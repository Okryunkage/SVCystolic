# Python 스크립트 역할과 실행 방법

이 폴더에는 직접 실행하는 평가·추출 프로그램 3개와 공통 Python 모듈 3개가 있다.
실물 평가에서는 PC 정규화 int8 입력, UART 8Mbps, MC50 명령04를 지원하는 FPGA 비트스트림을 사용한다.

## 파일별 역할

| 파일 | 역할 | 직접 실행 여부 |
|---|---|---|
| [export_mcdc.py](export_mcdc.py) | `.pt`의 가중치·bias를 양자화하고 FPGA용 `.mem` 생성 | 실행 |
| [evaluate_mnist_mc50.py](evaluate_mnist_mc50.py) | MNIST test 10,000개 전체에 대해 이미지당50회 추론 후 정확도 계산 | 실행 |
| [board_mc_cli.py](board_mc_cli.py) | MNIST·KMNIST·Fashion-MNIST를 함께 평가하여 ID 정확도와 OOD 구분 성능 계산 | 실행 |
| [board_client.py](board_client.py) | 정규화, UART 통신, 패킷 검사, MNIST 로딩, Python 정수 기준 CNN | 다른 스크립트가 import |
| [mc_metrics.py](mc_metrics.py) | softmax 확률 평균, entropy, mutual information, AUROC | 다른 스크립트가 import |
| [ood_data.py](ood_data.py) | OOD 데이터 다운로드·검사 및 혼합 평가 표본 선택 | 다른 스크립트가 import |
| [requirements-board.txt](requirements-board.txt) | 필요한 라이브러리 목록: NumPy와 pyserial | pip 설치에 사용 |

## 1. export_mcdc.py — 메모리 추출

입력은 `models/mcdc_int8_fixed/MCDC_int8_Fixed.pt`이다. 모델의 weight와 bias에
128을 곱하고 가장 가까운 정수로 반올림한 뒤 signed8 범위로 제한한다.
정확한 동점은 짝수로 반올림한다. Conv tile8, FC tile5에 맞게 여러8비트 값을
한 word에 배치한다. 생성된 word를 다시 풀어 양자화한 parameter와 같은지도 검사한다.

출력 위치는 `data/mcdc_int8_fixed/`이다.

| 생성 파일 | 내용 |
|---|---|
| `conv1_w.mem`, `conv1_b.mem` | Conv1 가중치·bias |
| `conv2_w.mem`, `conv2_b.mem` | Conv2 가중치·bias |
| `classifier_w.mem`, `classifier_b.mem` | FC 가중치·bias |
| `normalize.mem` | 원본 픽셀256개에 대한 정규화 기준표. CPU 기준 계산·검사용 |
| `validation.json` | checkpoint와 메모리 해시, 수치 스케일, parameter 검사 정보 |

현재 FPGA에는 정규화 LUT가 없다. 송신 Python은 정규화 식을 직접 계산한다.
`normalize.mem`은 `Reference`에서 정수 기준 입력을 만들 때 사용한다.
이 배포본의 추출기는 시뮬레이션 fixture를 생성하지 않으며, 기존 fixture도 요구하지 않는다.
지원하는 checkpoint는 현재 모델의 tensor 이름·shape·저장 형식에 맞춰져 있다.

```bat
python scripts\export_mcdc.py
```

가중치 `.mem`을 변경해 FPGA에 반영하려면 새 비트스트림을 생성하고 적용해야 한다.
스크립트를 실행하는 것만으로 연결된 보드의 가중치가 바뀌지는 않는다.

## 2. evaluate_mnist_mc50.py — MNIST 전체 정확도

MNIST 공식 test split의 index0~9999를 순서대로 모두 평가한다. train split,
KMNIST, Fashion-MNIST는 사용하지 않는다.

1. 원본 이미지를 PC에서 정규화한 int8로 변환해 한 번 전송한다.
2. FPGA가 새 마스크를 생성하며50회 추론하고, 매 회차 결과를 전송한다.
3. PC가 회차별 `softmax(scores/2048)`를 계산한다.
4. 50개 확률 벡터의 평균에서 가장 큰 클래스를 이미지의 최종 예측으로 선택한다.
5. MNIST 정답 label과 비교하여 전체 정확도를 계산한다.

총 FPGA 추론 수는500,000회이고, 정확도의 분모는 이미지 수10,000이다.
기본적으로100개마다 누적 정확도를 출력하고 마지막에 정답 수와 정확도(%)를 출력한다.

```bat
python scripts\evaluate_mnist_mc50.py --port COM6 --download
```

| 옵션 | 의미 |
|---|---|
| `--port COM6` | 보드가 연결된 USB-UART 포트 |
| `--download` | MNIST가 없으면 다운로드한 뒤 평가 |
| `--download-only` | MNIST 준비만 수행; 보드를 열지 않음 |
| `--list-ports` | COM 포트 목록 표시 |
| `--every 1` | 이미지마다 진행 결과 출력. 기본값100 |
| `--verify-scores` | 실제 mask를 Python 정수 CNN에도 적용해50회 모든 점수 비교 |
| `--output 경로` | 결과를 저장할 새 폴더 또는 빈 폴더 |

`--verify-scores`는 정확도 계산에 필수는 아니다. FPGA 연산이 Python과 같은지
추가로 확인하는 옵션이며 CPU 계산 시간이 늘어난다. 사용 전에 `.mem`을 추출해야 한다.

결과는 기본적으로 `output/mnist_mc50_runs/날짜_시간/`에 저장한다.

- `results.csv`: 이미지 index, 정답, 예측, 정오답, 누적 정확도, uncertainty 등.
- `summary.json`: 전체 정확도, 완료 여부, confusion matrix, 소요 시간 등.
- `samples.npz`: 이미지별50회 점수와 마스크, index와 정답 label.

Ctrl+C나 통신 오류가 발생하면 완료된 이미지까지만 저장하고 부분 정확도라고 표시한다.
부분 결과를 MNIST 전체 정확도로 표시하지 않는다.

## 3. board_mc_cli.py — ID/OOD 혼합 평가

기본 구성은 MNIST900개, KMNIST50개, Fashion-MNIST50개다. 각 데이터셋의
test split에서 중복 없이 선택한 뒤 섞어 평가한다. 이미지마다50회 추론한다.

```bat
python scripts\board_mc_cli.py --port COM6 --download --verify-scores
```

`--id-count`, `--kmnist-count`, `--fashion-count`로 이미지 수를 바꿀 수 있다.
`--seed`의 기본값42는 데이터 선택·순서를 재현하며 물리 RO의 난수를 재현하지 않는다.
`--quiet`는25개 이미지마다 진행 결과를 출력한다. `--download-only`,
`--list-ports`, `--output`도 지원한다.

정확도는 MNIST에 대해서만 계산한다. OOD label은 숫자의 정답이 아니므로
KMNIST·Fashion-MNIST에는 숫자 분류 정확도를 계산하지 않는다.
대신 entropy와 MI를 사용한 OOD AUROC를 계산한다. 자동 OOD 거절 임계값은 설정하지 않는다.
결과 CSV·JSON·NPZ는 `output/mc50_runs/날짜_시간/`에 저장한다.

## 4. board_client.py — 공통 통신과 정수 기준 모델

| 함수·클래스 | 역할 |
|---|---|
| `ports()` | 사용 가능한 직렬 포트 목록 |
| `load_mnist()` | MNIST 파일 다운로드, checksum·형식 검사 및 배열 로딩 |
| `normalize_image()` | float32 정규화·스케일32·반올림·포화로 uint8을 int8로 변환 |
| `make_packet()` | uint8이면 정규화, 이미 int8이면 그대로 요청 패킷 생성 |
| `decode_reply()` | 단일추론 응답46바이트 검사와 signed32 점수 복원 |
| `decode_mc_reply()` | MC 응답50바이트의 header·checksum·상태·회차·예측 검사 |
| `Board` | 8Mbps/8N1 포트 열기·닫기와 송수신 |
| `Board.infer()` | 명령03의 단일추론 수행 |
| `Board.infer_mc()` | 명령04로 이미지 한 번 전송 후50개 회차 응답 수집 |
| `Reference` | 추출한 `.mem`을 읽어 동일한 정수 CNN과 채널 마스크 계산 |

명령03 지원은 공통 모듈에 남아 있지만, 이 폴더의 두 평가 프로그램은 명령04를 사용한다.
`Board.infer_mc()`의 반환 점수 배열은 `[50,10]`, 마스크 배열은 `[50,2]`다.
각 마스크 조합은 Conv1의8비트와 Conv2의16비트로 구성된다.
`masks=49/50`은 추론49회를 뜻하지 않고,50회 중 서로 다른 조합이49개라는 뜻이다.

## 5. mc_metrics.py — 확률과 불확실성

`uncertainty(scores)`는 회차별 점수에 softmax를 적용한 뒤 평균 확률을 계산한다.
평균 확률의 argmax가 최종 예측, 최댓값이 confidence다.

- Predictive entropy: 평균 확률의 불확실성.
- Expected entropy: 회차별 entropy의 평균.
- Mutual information(MI): predictive entropy에서 expected entropy를 뺀 값.

entropy 단위는 자연로그의 nat이다. 점수를 먼저 평균내고 softmax를 적용하는 방식이나
회차별 예측의 다수결과는 다르다.
`auroc()`는 높은 불확실성 점수가 OOD를 얼마나 잘 구분하는지 계산한다.
MNIST 전용 평가에서는 OOD AUROC를 계산하지 않는다.

## 6. ood_data.py — 혼합 평가 데이터 준비

`load_dataset()`은 데이터셋을 로딩하고 다운로드 파일의 MD5·IDX 형식을 검사한다.
MNIST는 `board_client.load_mnist()`를 사용하고, KMNIST와 Fashion-MNIST는
각 데이터셋의 test 파일을 준비한다. 이미지는28×28 uint8 상태로 반환한다.
정규화는 이후 공통 송신 경로에서 수행한다.

`mixed_indices()`는 지정한 수만큼 중복 없는 index를 선택하고 데이터셋을 섞는다.
MNIST 전체 평가 프로그램은 이 모듈을 사용하지 않고 index0~9999를 그대로 순회한다.

## 준비 및 실행 순서

아래 명령은 Anaconda Prompt에서 프로젝트 루트를 기준으로 실행한다.

```bat
cd /d C:\Users\user\Desktop\gpt\CNN_MC50_Source
pip install -r scripts\requirements-board.txt
python scripts\export_mcdc.py
python scripts\evaluate_mnist_mc50.py --port COM6 --download
```

평가에는 새8Mbps 비트스트림이 적용된 보드가 필요하다. 데이터 다운로드와 메모리
추출에는 보드가 필요하지 않다. 포트 번호는 실제 연결 환경에 맞춘다.
두 평가 프로그램을 같은 포트에서 동시에 실행하지 않는다.

공통 모듈은 평가 프로그램과 같은 `scripts` 폴더에 둔다. 프로젝트 위치를 옮겨도
Python은 스크립트 위치를 기준으로 모델·데이터·결과 경로를 찾는다.
