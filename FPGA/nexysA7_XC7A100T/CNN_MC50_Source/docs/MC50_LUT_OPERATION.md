> 소스 배포본: 실행 순서는 [README](../README.md)를 따른다. 검증 수치는 기존 개발본의 기록이며, 빌드·평가 결과 파일은 포함하지 않는다. 이 폴더의 export_mcdc.py는 모델 메모리와 CPU 정규화 표만 생성하고 시뮬레이션 fixture는 생성하지 않는다.

# LUT SNG 기반 MC50 동작

## 데이터 흐름

```text
원본 uint8 → PC 정규화 int8 → UART → 입력 BRAM에 한 번 저장
  → 50회 반복:
       RO bank → 동기화/XOR → LUT SNG → 채널 mask
       Conv1 → mask1 → pool1 → Conv2 → mask2 → pool2 → FC
       UART로 iteration 번호 + mask 두 개 + 점수 10개 송신
  → PC: 회차별 softmax → 확률 평균 → 최종 예측과 uncertainty
```

CNN은 100MHz, UART는 8Mbps/8N1이다. MC 요청 하나당 입력 패킷789바이트를
한 번 보내고 50바이트 응답50개(총2500바이트)를 받는다. 계산과 응답 전송은
회차마다 순차 실행한다. 50개 응답을 다 받기 전에 다음 이미지를 보내지 않는다.
명령03은 기존 mask 없는 단일 추론을 유지한다.

## RO와 LUT SNG

`rtl/rng/RO.v`, `rtl/rng/sng_lut.v`가 RO 및 LUT6 확률 변환을 구현한다.
`lutRngSource.sv`에는 3개 inverter로 구성한 RO 13개가 있다. 각 RO의 비동기
출력에는 원본 RO의 enable/출력 buffer도 포함된다. 비동기 출력을 sampleMeta/sampleSync 두 단계에서 샘플한 뒤 XOR하고 한 번 더 등록한다.
이 비트 스트림을 4비트 word로 모아 LUT6에서 drop 여부를 결정한다.

| 레이어 | LUT threshold | 이상적인 drop 확률 | keep 확률 |
|---|---:|---:|---:|
| Conv1 | 2 | 2/16 = 0.125 | 0.875 |
| Conv2 | 3 | 3/16 = 0.1875 | 0.8125 |

4비트 해상도에서 각각 0.1, 0.2에 가장 가까운 값이다. 학습 시의 정확한
0.1/0.2와 차이가 있으므로 모델 정확도와 uncertainty는 실제 mapping으로 평가한다.
LUT가1이면 drop, 저장되는 mask가1이면 keep이므로 mask에 넣을 때 반전한다.
이미 확률을 적용한 SNG 출력에 기존 decimal rejection을 다시 적용하지 않는다.

두 LUT는 같은 rawBit와 sample timing을 사용하지만, 하나의 word를 두 레이어의
채널에 동시에 할당하지 않는다. mask generator가 먼저 Conv1의8개 채널, 다음에
Conv2의16개 채널을 순차 소비한다. 한 채널마다 새 유효 word를 사용한다.
mask 생성 중이 아닐 때의 SNG 출력은 버린다. 재시작마다 RO를 reset하지 않는다.
각 회차의 mask는 그 회차 전체 공간 위치에서 고정된다. 중복 mask는 허용된다.
keep 채널에 1/(1-p) 보정은 적용하지 않는다.

목표 확률은 4비트 word가 균등할 때의 값이다. 실제 RO의 편향과 샘플 상관은
타이밍 시뮬레이션만으로 증명되지 않는다. CLI는 실제 mask의 drop 비율과
회차별 mask 다양성을 저장한다. 이는 관찰값이며 RNG 독립성/엔트로피 인증은 아니다.

`RNG_SIMULATION` define은 기능 시뮬레이션에만 재현 가능한 xorshift 자극을
사용한다. 물리 합성에서는 define하지 않으며 실제13개 RO가 보존됐는지 검사한다.
`constraints/rng.xdc`는 RO 내부의 의도된 조합 루프만 허용하고, 첫 샘플링 FF로
들어가는 비동기 경로를 제외한다. CNN 경로는 정상100MHz 타이밍 검사를 받는다.

## 명령과 응답

요청은 `A5 5A command normalized_int8[784] sum16LE`이며 checksum은 command+전송 payload byte값(0~255)의 합이다.

- command03: `5A A5 status prediction scores[10]LE checksumLE`, 46바이트.
- command04: 다음 50바이트 프레임을 iteration0~49 순서로50번 전송.

| byte offset | MC 프레임 내용 |
|---|---|
| 0~1 | 5A A6 |
| 2 | status: 정상00, 오류E1/E2/E3/E4 |
| 3 | iteration0~49 |
| 4 | 해당 회차 argmax 클래스, 오류 시FF |
| 5 | mask1: 8개 채널, bit0=채널0 |
| 6~7 | mask2: 16개 채널, little endian |
| 8~47 | signed32 score10개, 클래스0~9, little endian |
| 48~49 | byte2~47 합의 하위16비트, little endian |

MC 요청의 수신 오류는 error frame 하나를 보내고 종료한다. command를 식별하기
전 오류는 기본46바이트 응답이 될 수 있다. Python은 두 header와 status를 검사한다.
계산 중 새 요청을 수용하는 FIFO는 없다. 이미지 BRAM은50회 동안 유지된다.

LED LD0~LD3은 패킷 진행/CNN busy/resultValid/error, LD4~LD7은 마지막 회차의
예측 bit0~3이다. PC에서 계산한50회 평균 예측은 LED에 되돌려 쓰지 않으므로
마지막 회차 LED와 최종 PC 예측은 서로 다를 수 있다.

## Feature 메모리의 width와 address depth

width는 한 주소에서 읽고 쓰는 word의 비트 수, depth는 유효한 word 개수다.
address width는 그 주소를 표현하는 비트 수이며 depth 자체와 다르다.

| 메모리 | 논리 데이터 | word width | address depth | 유효 주소 | address width | payload |
|---|---|---:|---:|---|---:|---:|
| 입력 image | 1×28×28, signed8 | 8bit | 784word | 0~783 | 10bit | 784B |
| Conv1 pooled feature | 8×14×14, unsigned8 | 64bit | 196word | 0~195 | 8bit | 1568B |
| Conv2 pooled feature | 16×7×7, unsigned8 | 64bit | 98word | 0~97 | 7bit | 784B |

feature word의 lane0은 bits7:0, lane1은15:8, …, lane7은63:56이다.

```text
word width   = tile × actWidth = 8 × 8 = 64
address depth = (outChannels / tile) × pooledHeight × pooledWidth
address width = ceil(log2(address depth))
address = (channel / 8) × H × W + row × W + column
lane = channel % 8
```

Pool1은8개 채널이 모두 한 tile이므로196개의 공간 위치마다 word 하나다.
Pool2는 채널0~7의49word, 채널8~15의49word로 총98word다.
주소 폭 때문에 Pool1 주소196~255와 Pool2 주소98~127도 비트로 표현할 수
있지만 논리적으로 유효하지 않아 읽기 조건에서 제외한다.

이 값은 payload이고 실제 BRAM은18/36Kbit 단위의 배치·폭 제약 때문에 여유
공간이 생긴다. 두 feature 메모리는 모두 single-port XPM, READ_LATENCY_A=2다.
레이어 계산 중 write하고 다음 레이어가 시작되면 read한다. MC50은 같은 feature
BRAM을 매회 덮어쓰므로 width/depth를50배 늘리지 않는다. FC는 이 word를 채널
우선 flatten 순서로 선택하며 784개의 scalar 입력을 구성한다.

## Python 최종 예측과 uncertainty

각 회차 score를2048로 나눈 logit에 안정적인 softmax를 적용한다.

```text
p[t] = softmax(scores[t] / 2048), t=0..49
mean_p = mean(p[t], axis=t)
prediction = argmax(mean_p)
confidence = max(mean_p)
predictive_entropy = -sum(mean_p * log(mean_p))
expected_entropy = mean(-sum(p[t] * log(p[t])))
mutual_information = predictive_entropy - expected_entropy
```

entropy 단위는 자연로그의 nat이며 클래스10개에서 최대값은 ln(10)이다.
predictive entropy는 평균 예측의 불확실성, expected entropy는 회차별 불확실성의
평균, MI는 회차 간 예측 차이에 해당하는 양이다. 점수 평균 후 softmax나 다수결을
쓰지 않는다. uncertainty가 높다고 항상 OOD인 것은 아니고 자동 거절 임계값도 설정하지 않는다.

## 900 ID + 100 OOD CLI

기본 표본은 공식 test split에서 중복 없이 추출한 MNIST900개, KMNIST50개,
Fashion-MNIST50개다. seed42는 표본 선택과 순서를 재현하며 물리 RNG 시퀀스를
재현하지 않는다. 모든 데이터는 원래28×28 uint8를 사용하고 PC의 동일한
MNIST normalization을 거친다. OOD에 별도 학습이나 정규화를 적용하지 않는다.

```bat
cd /d C:\Users\user\Desktop\gpt\CNN_MC50_Source\scripts
python board_mc_cli.py --download-only
python board_mc_cli.py --port COM6 --verify-scores
```

`--verify-scores`는 전송된 각 mask로 Python 정수 CNN을 계산해50회 모든 점수를
비교한다. 이 옵션을 생략하면 실제 보드 점수로 uncertainty를 계산하되 CPU
점수 비교는 생략한다. `--quiet`는25개 이미지마다 진행 결과를 표시한다.
`--id-count`, `--kmnist-count`, `--fashion-count`, `--seed`, `--output`으로
표본 구성과 결과 경로를 지정할 수 있다. 평가 진입점은 `board_mc_cli.py`다.

결과는 새 `output/mc50_runs/날짜_시간/` 폴더에 저장된다.

| 파일 | 내용 |
|---|---|
| results.csv | dataset/index, ID/OOD, 원래 label, 최종 예측, ID 정오답, uncertainty, mask 다양성, 시간 |
| samples.npz | scores[N,50,10], masks[N,50,2], dataset 이름과 index |
| summary.json | ID 정확도, 데이터별 uncertainty 평균, OOD AUROC, 실제 drop 비율, 오류/완료 여부 |

OOD label의0~9는 일본어 글자/의류 분류 번호이지 숫자 정답이 아니다. 따라서
MNIST에 대해서만 정확도를 계산하고 OOD 행의 id_correct는 비워둔다. OOD를
positive로 하여 높은 entropy/MI가 OOD를 구분하는 정도를 AUROC로 기록한다.
이 test set에서 threshold를 맞춰 검증 성능으로 보고하지 않는다.

데이터 출처와 파일 checksum 기준:
[MNIST/파생 데이터 로더](https://github.com/pytorch/vision/blob/main/torchvision/datasets/mnist.py),
[KMNIST](https://github.com/rois-codh/kmnist),
[Fashion-MNIST](https://github.com/zalandoresearch/fashion-mnist).

## 빌드와 검사

Vivado 소스 구성은 [README](../README.md#vivado-소스-구성),
현재 기능·실물 검증 결과는 [검증 기록](INT8_8MBPS_VALIDATION.md)을 참조한다.
시뮬레이션과 빌드 스크립트는 이 소스 배포본에 포함하지 않는다.

PC 정규화 식·명령03/04·fractional baud의 상세 설명은 [PC 정규화와8Mbps](HOST_NORMALIZE_8MBPS.md)를 참조한다.
