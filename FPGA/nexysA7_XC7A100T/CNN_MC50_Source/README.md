# CNN MC50 소스 패키지

Nexys A7-100T,100MHz,UART8Mbps. PC에서 정규화한 int8을 전송하고 FPGA는
RO/LUT 마스크로50회 추론한다. PC가 최종 예측·entropy·MI를 계산한다.

각 Python 파일의 역할과 실행 옵션: [스크립트 안내](scripts/README.md).

## 폴더 구성

| 경로 | 내용 |
|---|---|
| rtl/ | 현재 RTL17개 파일, 제공된 RO.v와 sng_lut.v 포함 |
| rtl.f | Vivado에 추가할 RTL 목록 |
| constraints/ | Nexys 핀·100MHz 클럭 및 RO 제약 |
| models/mcdc_int8_fixed/MCDC_int8_Fixed.pt | 학습 checkpoint |
| scripts/export_mcdc.py | .pt에서 weight/bias .mem6개와 normalize.mem 생성 |
| scripts/evaluate_mnist_mc50.py | MNIST test10000개 전체,각50회 추론 후 정확도 평가 |
| scripts/board_mc_cli.py | MNIST900+KMNIST50+Fashion50,각50회 실물 평가 |
| scripts/board_client.py | UART8Mbps,PC 정규화,패킷 및 정수 기준 모델 |
| scripts/mc_metrics.py | softmax 평균·entropy·MI·AUROC |
| scripts/ood_data.py | OOD test 데이터 다운로드·검사·표본 선택 |
| docs/ | 구조·동작·검증 기록 MD |

비트스트림,Vivado 프로젝트/빌드 로그,가상환경,데이터셋,기존 평가 결과와
생성된 .mem은 포함하지 않는다. 원본 작업 폴더는 별도로 유지된다.

## 실행 순서

Anaconda Prompt에서:

```bat
cd /d C:\Users\user\Desktop\gpt\CNN_MC50_Source
pip install -r scripts\requirements-board.txt
python scripts\export_mcdc.py
python scripts\board_mc_cli.py --download-only
python scripts\board_mc_cli.py --port COM6 --verify-scores
```

1. 추출 스크립트가 data/mcdc_int8_fixed/에 .mem7개와 validation.json을 만든다.
   weight/bias의 양자화·packing은 개발본과 동일하고,생성 word를 다시 풀어 검사한다.
   이 배포본에서는 별도 fixture 없이 .pt만으로 추출할 수 있다.
2. 다운로드 명령이 공식 test 데이터를 data/에 저장한다.
3. 평가는 보드에 PC 정규화·8Mbps용 비트스트림이 적용된 상태에서 실행한다.
   명령03/04를 사용하며 이전1Mbps/원본 uint8 펌웨어와 호환되지 않는다.
4. 결과는 output/mc50_runs/에 생성된다.

normalize.mem은 CPU 기준 계산용이다. FPGA에는 정규화 LUT가 없고,
Python 송신 경로는 float32 정규화 식으로 직접 계산한다.

## Vivado 소스 구성

대상 part는 xc7a100tcsg324-1,top은 mnistUartBRAMTOP이다. rtl.f의 파일과
constraints/의 두 XDC,추출한 data/mcdc_int8_fixed/*.mem을 추가하고
XPM_MEMORY를 활성화한다. 메모리 경로를 해석할 수 있도록 이 폴더를 작업
기준으로 사용하거나 parameterDir를 생성된 메모리 폴더에 맞춘다.
합성에서 RNG_SIMULATION 또는 CONV_XPM_SIM을 정의하지 않는다.
현재 비트스트림은 별도 개발본에 있으며 이 패키지는 소스 배포본이다.

[전체 구조](docs/FPGA_CNN_FULL_GUIDE_KO.md) ·
[PC 정규화와8Mbps](docs/HOST_NORMALIZE_8MBPS.md) ·
[MC50 동작](docs/MC50_LUT_OPERATION.md)

## MNIST ID test 전체10000개 평가

```bat
cd /d C:\Users\user\Desktop\gpt\CNN_MC50_Source
python scripts\evaluate_mnist_mc50.py --port COM6 --download
```

MNIST 공식 test split의 index0~9999를 순서대로 모두 평가한다. OOD와 train
이미지는 사용하지 않는다. 이미지마다 FPGA50회 추론 후 각 회차 softmax의
평균으로 예측 하나를 결정한다. 총500000회 FPGA 추론이며 정확도의 분모는
이미지10000개다.100개마다 누적 정확도,마지막에 전체 정답 수와 정확도(%)를 출력한다.

--every1로 이미지마다 출력할 수 있다(명령에서는 `--every 1`).
--verify-scores를 추가하면 각 회차의 실제 mask로 Python 정수 CNN을 계산해
점수를 비교한다. 기본값에서는 정확도를 계산하되 CPU 점수 비교는 생략한다.
CPU 비교를 사용할 때는 export_mcdc.py로 메모리를 먼저 생성해야 한다.

결과는 output/mnist_mc50_runs/의 새 폴더에 results.csv,summary.json,
samples.npz로 저장한다. CSV에는 정답·예측·누적 정확도와 uncertainty가,
NPZ에는50회 점수와 마스크가 들어간다. summary에는 전체 정확도,완료 여부와
confusion matrix(행=정답,열=예측)를 저장한다.
Ctrl+C나 통신 오류 시 완료된 이미지까지만 저장하고 부분 정확도임을 표시한다.
오류 또는 점수 불일치가 있으면 종료 코드는1이다.
실물에는 PC 정규화·8Mbps·명령04를 지원하는 비트스트림이 필요하다.
