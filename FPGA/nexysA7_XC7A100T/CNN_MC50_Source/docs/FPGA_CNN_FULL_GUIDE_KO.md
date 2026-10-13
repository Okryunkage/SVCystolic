> 소스 배포본: 실행 순서는 [README](../README.md)를 따른다. 검증 수치는 기존 개발본의 기록이며, 빌드·평가 결과 파일은 포함하지 않는다. 이 폴더의 export_mcdc.py는 모델 메모리와 CPU 정규화 표만 생성하고 시뮬레이션 fixture는 생성하지 않는다.

# FPGA CNN 전체 구조·변수·로직 해설서


작성 기준: 2026-10-13, `CNN_BRAM_UART/rtl.f`의 17개 RTL 파일과 현재 Python CLI.
목적: 소스를 읽으며 모듈의 역할, 변수의 의미, 상태 전이, 수치 표현과 시간 관계를
함께 이해하기 위한 학습·유지보수 문서다. 코드 자체를 변경하는 문서는 아니다.

읽는 순서: 1~10장은 큰 흐름, 11~13장은 LUT SNG와 MC50 동작, 14장부터는 파일별
변수/상태 머신과 구체적 예제다. 처음 읽을 때는 1~10 → 14~25 → 11~13 순서를 권장한다.

| 범위 | 내용 |
|---|---|
| 1~8 | 전체 경로, UART, 입력 저장, CNN 연산, 메모리, 제어 |
| 9~10 | LED와 UART 교체 계약 |
| 11~13 | SNG·MC50, PC 확률 평균과 uncertainty |
| 14~15 | RTL 문법과 파라미터, 소스 지도 |
| 16~18 | UART, 패킷 FSM, CNN FSM 변수와 상태 |
| 19~21 | 입력/파라미터 메모리, Conv 입력 reader |
| 22~25 | Conv wrapper/core, pooling, FC |
| 26~28 | 수치 보조 모듈, mask, 클럭/리셋/제약 |
| 29~32 | Python, 검증, 수정 시 확인 사항, 용어·디버깅 |

명령03은 mask 없는 단일 추론, 명령04는 LUT SNG로 매회 mask를 생성하는50회 추론이다.
최종 확률 평균과 uncertainty는 PC에서 계산한다. 패킷과 실행 방법은
[MC50 동작 설명](MC50_LUT_OPERATION.md)에 정리되어 있다.

## 1. 전체 흐름

```text
PC Python
  │ 789 bytes, UART 8 Mbps / 8N1
  ▼
mnistUart: 핀의 직렬 비트 ↔ 8비트 바이트
  ▼
mnistUartBRAMTOP: 패킷 해석, 체크섬, 이미지 쓰기, start, 결과 송신
  ▼
mnistBRAMTOP: 한 번의 CNN 실행 순서 제어
  ├─ mnistImageMEM: 수신 int8 → 입력 BRAM에 그대로 저장
  ├─ dropChannelMask: MC 모드일 때만 8+16개 채널 mask 생성
  ├─ conv1: 입력 reader + 파라미터 ROM + 8-lane MAC + ReLU/양자화/mask/pool
  │          └─ pooled feature BRAM: 8×14×14
  ├─ conv2: 입력 reader + 파라미터 ROM + 8-lane MAC + ReLU/양자화/mask/pool
  │          └─ pooled feature BRAM: 16×7×7
  ├─ fcInputReader + fcCore + fcMemory: 784 → 10
  └─ argmax_pipe: 가장 큰 점수의 클래스 번호
  │
  ▼
명령03:46바이트 / 명령04:50바이트×50회 → Python 화면/CSV
```

계산은 100MHz 하나의 클럭을 기준으로 진행한다. UART 8Mbps는 별도 CNN
클럭이 아니라 한 직렬 비트당 평균12.5개의100MHz 클럭을 쓰는 통신 속도다.
phase 누산기로12/13클럭 간격을 생성한다.

## 2. UART 바이트와 패킷은 서로 다른 계층

`mnistUart.sv`는 8N1의 start bit, data 8 bits(LSB first), stop bit를 처리한다.
RX 입력은 2단 플립플롭으로 동기화한 뒤 start bit의 중간 지점과 각 data bit의
중간 지점을 샘플링한다. stop bit가 0이면 framing error를 알린다.
TX는 요청된 바이트 앞뒤에 start/stop을 붙여 보낸다. idle TX는 1이다.

이 모듈은 MNIST나 CNN을 알지 못한다. 의미 있는 패킷 해석은
`mnistUartBRAMTOP.sv`가 담당한다.

단일추론 요청은 `A5 5A 03 + normalized int8 784 bytes + checksum 2 bytes`다.
MC50은 command만04로 바뀌며 이미지 전송량은 동일하다.
픽셀 순서는 위에서 아래, 각 행은 왼쪽에서 오른쪽이다. checksum은
command와784개 전송 byte값(0~255)의 합을 16비트로 자른 값이며 low byte부터 전송한다.
따라서 요청은 789바이트다.

픽셀은 수신되는 동안 순서대로 입력 메모리에 기록한다. 마지막 checksum이
일치하고 이미지 로드가 완료됐을 때만 CNN을 시작한다. 오류가 난 이미지도
일부가 메모리에 쓰여 있을 수 있지만 추론하지 않으며, 다음 정상 요청이
주소 0부터 전체 이미지를 다시 덮어쓴다.

응답은 `5A A5 + status + prediction + signed32 scores[10] + checksum`으로
46바이트다. 점수와 checksum 모두 little endian이다. 성공 status는 00,
오류는 E1(checksum), E2(framing), E3(inter-byte timeout), E4(command)다.
에러 응답의 prediction은 FF, scores는 0이다.

현재는 한 이미지만 처리한다. CNN 계산/결과 송신 중 다음 이미지를 저장할
별도 버퍼가 없으므로 명령03은 응답46바이트, 명령04는 응답50바이트×50개를 모두 받은 뒤 다음 요청을 보낸다.
기본 수신 중 바이트 간 timeout은 500ms다.

## 3. 입력 BRAM과 정규화

`mnistImageMEM.sv`는 0~783의 순차 쓰기를 검사한다. 주소 0은 새 이미지
시작이며 마지막 주소 783이 정상적으로 기록되면 loaded가 1이 된다.

PC의 normalize_image()가 원본 픽셀 v를 float32 연산과 rint(동점은 짝수)로 다음 정수로 바꾼다.

```text
x_int = clip(round(((v / 255 - 0.1307) / 0.3081) × 32), -128, 127)
```

PC가 이 signed8의 비트패턴을 전송하고 FPGA는 그대로784×8bit XPM BRAM에 저장한다.
normalize.mem은 CPU 기준/회귀 테스트용이며 FPGA에는 normalizeTable이 없다.
모든 픽셀이 수신된 뒤에는 쓰기 없이 읽기만 한다. 같은 이미지를 반복
추론할 때 입력을 다시 보낼 필요는 없다. start만으로 이미지가 지워지지 않는다.

## 4. CNN의 형태와 숫자 표현

| 단계 | 형태(C×H×W) | 연산 |
|---|---|---|
| 입력 | 1×28×28 | signed8 정규화 |
| Conv1 | 8×28×28 | 3×3, stride1, padding1 |
| 활성화/mask | 8×28×28 | ReLU, unsigned8 재양자화, 채널 mask |
| Pool1 | 8×14×14 | 2×2 max pool, stride2 |
| Conv2 | 16×14×14 | 3×3, stride1, padding1 |
| 활성화/mask | 16×14×14 | ReLU, unsigned8 재양자화, 채널 mask |
| Pool2 | 16×7×7 | 2×2 max pool, stride2 |
| FC | 10 | 채널 우선 flatten 784개 입력 |

가중치와 bias는 제공된 학습 코드에 맞춰 `round(value×128)` 후
signed8 범위로 제한한 Q7 값이다. 저장된 .pt 자체는 float32였지만 실제
학습 forward에서 이 양자화를 적용했다.

| 구간 | 정수 계산 | 정수값의 실수 스케일 |
|---|---|---|
| Conv1 누산 | Σ(x_int×w_int) + (b_int<<5) | 4096 |
| Conv1 출력 | ReLU 후 반올림 >>7, 0~255 포화 | 32 |
| Conv2 누산 | Σ(a1_int×w_int) + (b_int<<5) | 4096 |
| Conv2 출력 | ReLU 후 반올림 >>8, 0~255 포화 | 16 |
| FC 점수 | Σ(a2_int×w_int) + (b_int<<4) | 2048 |

누산기와 최종 점수는 signed32다. Conv 이후 활성값은 음수가 없으므로
unsigned8이다. 가중치는 음수가 가능하므로 곱셈 직전에 입력 signed/unsigned를
구분해 확장한다. UART의 점수를 2048로 나누면 근사 logit이다.
현재 FPGA는 softmax를 계산하지 않는다. argmax에는 공통 양의 스케일이
영향을 주지 않는다.

학습 Python은 중간 활성값을 실수로 유지한다. FPGA는 활성값까지 8비트로
반올림/포화하므로 학습 모델과 완전히 같은 실수 연산은 아니다. 앞서 얻은
98.4%는 이 FPGA 정수 모델의 MNIST 테스트 앞 1,000개에 대한 실제 결과다.

## 5. tile과 병렬 연산

Conv의 tile=8은 출력 채널 8개를 동시에 누산한다는 뜻이다. 한 클럭의
유효 MAC에서 입력 scalar 하나를 8개 lane에 공통으로 주고, 서로 다른
8개 weight와 곱해 각각의 accumulator에 더한다.

- Conv1은 출력 채널이 8개이므로 한 tile이다. 한 출력 위치당 입력 항은 1×3×3=9개.
- Conv2는 출력 채널이 16개이므로 두 tile을 순차 실행한다. 한 출력 위치당 8×3×3=72개.
- FC는 tile=5이며 클래스 0~4, 5~9의 두 tile을 순차 실행한다. 각 tile은 784개 항을 누산한다.

이미지의 모든 픽셀이나 모든 레이어가 동시에 계산되는 구조는 아니다.
Conv1 완료 → Conv2 완료 → FC 완료 순서다. 입력을 요청하고 피연산자를
등록하는 과정은 파이프라인으로 겹치지만 레이어 실행 자체는 순차다.
검증한 구현에서는 곱셈이 LUT로 구현되어 DSP 사용량은 0이다.

## 6. reader, BRAM 지연, pooling

`convInputReader`는 출력 row/column과 kernel term을 실제 입력 좌표로
변환한다. padding 위치라면 BRAM을 읽지 않고 같은 지연의 0을 반환한다.
여러 채널이 한 word에 묶여 있으면 해당 lane만 선택한다. term의
채널/커널 좌표는 상수 LUT에서 읽어 복잡한 런타임 나눗셈을 줄였다.

입력과 weight BRAM의 read latency는 2클럭이다. 두 응답을 맞춰
inputRegister/weightRegister에 저장하고 다음 단계에서 곱셈과 누산을 한다.
마지막 read 응답을 받은 순간이 아니라 마지막 MAC까지 끝나야 출력으로
넘어간다. valid 파이프라인은 이 순서를 보장한다.

`maxPool`은 출력 feature 전체를 모아두지 않고 순서대로 들어오는 값을
처리한다. 이전 행과 왼쪽의 비교 이력을 유지해 2×2 최대값을 만든다.
전체 feature map은 BRAM에 저장하지만 이 작은 pooling 이력은 별도로 존재한다.
새 tile의 시작 때 좌표를 초기화하며 첫 유효 window 전에 이력이 덮어써진다.

## 7. feature 메모리와 FC flatten

한 word는 8개 채널 값이 들어간 64비트이며 lane0은 가장 낮은 8비트다.

```text
word address = (channel / 8) × H × W + row × W + column
lane         = channel % 8
```

Pool1은 196×64비트, Pool2는 98×64비트다. Pool2의 앞 49word는 채널0~7,
뒤 49word는 채널8~15다. word 내부에는 같은 위치의 8개 채널이 있다.

PyTorch flatten은 한 채널의 49개 위치를 먼저 훑는다. 따라서
`fcInputReader`가 logical index를 word address와 lane으로 변환해야 한다.
주소/선택 정보 LUT는 feature를 복제한 저장소가 아니라 metadata다.

파라미터 메모리는 각 레이어의 weight/bias 2개씩 총 6개, 입력 메모리 1개,
feature 메모리 2개로 총 9개 XPM SPRAM 인스턴스가 있다. 실제 사용량은
BRAM tile 10개다. 인스턴스 수와 물리 BRAM block 수는 같지 않다.

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

## 8. 현재 start, busy, done, resultValid

`mnistBRAMTOP`은 idle이고 이미지가 loaded이며 이미지 쓰기가 없을 때 start를
수락한다. mcMode=0이면 mask 생성 없이 Conv1부터 시작하고, mcMode=1이면
MASK_START/MASK_WAIT를 거쳐 새 mask를 생성한다.

각 레이어의 done을 기다리며 다음 레이어를 시작한다. FC 이후 argmax는
10→5→3→2→1의 등록된 비교 트리다. 동점은 작은 클래스 번호를 선택한다.
완료 때 done은 1클럭 pulse이고 resultValid는 유지된다. 새 이미지 쓰기나
다음 start가 resultValid를 내린다. 점수와 예측도 다음 계산 전까지 남는다.

현재 단일 deterministic 추론은 42,774클럭, 100MHz에서 약 0.428ms다.
UART 순수 전송 시간은 요청0.98625ms + 단일 응답0.0575ms다. 실제 PC 왕복에는
USB/OS 시간이 포함되며 이전1Mbps/단일추론1000개 검사 평균14.83ms는8Mbps 실측값이 아니다.

## 9. LED의 정확한 의미

RTL의 연결은 다음과 같다.

```systemverilog
assign led = {prediction, status != 0, resultValid, nnBusy, state != HEADER0};
```

| LED | 의미 | 설명 |
|---|---|---|
| LD0 | UART controller가 HEADER0 상태가 아님 | 요청 수신/추론/응답 송신 중. RX bit 자체 아님 |
| LD1 | CNN busy | CNN 한 회 실행 중. 0.428ms 정도라 눈으로 보기 어려울 수 있음 |
| LD2 | resultValid | 계산 결과가 존재함. 다음 이미지 쓰기/추론 전까지 유지 |
| LD3 | status!=0 | UART/protocol 오류 상태. 다음 요청 header 시작 또는 reset에서 해제 |
| LD4 | prediction bit0 | 숫자 코드의 1 자리 |
| LD5 | prediction bit1 | 숫자 코드의 2 자리 |
| LD6 | prediction bit2 | 숫자 코드의 4 자리 |
| LD7 | prediction bit3 | 숫자 코드의 8 자리 |

예측 7은 LD6/LD5/LD4가 켜지고 LD7은 꺼진다. 응답 송신까지 끝나면
LD2도 켜져 전체 led[7:0]는 0x74다. 예측 2라면 0x24다.
이 LED는 예측을 표시할 뿐, 정답을 맞혔다는 뜻은 아니다. FPGA는 label을
받지 않으므로 정오답 비교는 Python에서 한다. LD2도 정확도 표시가 아니다.

오류가 난 경우에는 이전 성공 추론의 prediction/resultValid가 남을 수도
있다. 오류 여부는 LD3와 UART status를 함께 해석해야 한다.
이 설계는 LD0~LD7만 출력으로 연결한다. LD8~LD15 의미는 정의하지 않았다.

MC50에서도 LED 예측은 마지막 회차의 argmax이다. PC의50회 평균 예측은 LED에 표시되지 않는다.

## 10. 다른 UART 모듈로 교체

교체 가능하다. `mnistUartBRAMTOP`의 serialPort 인스턴스와 byte 인터페이스를
맞추면 CNN/BRAM 계산부는 그대로 사용할 수 있다.

| 신호 | 방향(UART 관점) | 계약 |
|---|---|---|
| clk/rst | 입력 | 100MHz, 내부 active-high synchronous reset |
| rx / tx | 입력 / 출력 | UART 핀, 8Mbps 8N1, idle=1 |
| rxData[7:0] | 출력 | 수신 완료 바이트 |
| rxValid | 출력 | rxData가 유효한 1클럭 pulse |
| rxError | 출력 | framing error의 1클럭 pulse |
| txData[7:0] | 입력 | 보낼 바이트 |
| txStart | 입력 | idle에서 1클럭 요청, 그 edge에서 데이터 수락 |
| txBusy | 출력 | 요청 수락 후 전송 중이면 1 |
| txDone | 출력 | stop bit까지 전송 완료했을 때 1클럭 pulse |

교체할 모듈의 valid가 baud tick 동안 유지되는 level이거나, txDone 대신
ready만 제공한다면 adapter가 필요하다. 다른 클럭이면 CDC/FIFO도 검토해야 한다.
TX 요청과 완료가 중복/누락되지 않는 것이 핵심이다. 핀은 FPGA RX=C4,
FPGA TX=D4다. 교체하면 RX 첫 동기화 레지스터 이름에 걸린 XDC false path도
새 계층에 맞춰 수정해야 한다. 기존 검증 결과가 새 UART에도 자동 적용되지는 않는다.

## 11. MC50 반복과 데이터 흐름

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

마스크는 회차마다 생성하고 회차 내부에서는 고정한다. 동일 mask가 다시 나오는 것은
허용된다. drop된 채널도 MAC을 수행한 뒤 출력을0으로 하므로 연산 시간은 줄지 않는다.

## 12. PC 확률 평균과 uncertainty

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

## 13. RO와 LUT SNG 연결

`rtl/rng/RO.v`, `rtl/rng/sng_lut.v`가 RO 및 LUT6 확률 변환을 구현한다.
`lutRngSource.sv`에는 3개 inverter로 구성한 RO 13개가 있다. 각 RO의 비동기
출력을 sampleMeta/sampleSync 두 단계에서 샘플한 뒤 XOR하고 한 번 더 등록한다.
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

## 14. RTL을 읽는 데 필요한 문법과 파라미터

### 14.1 조합 회로와 순차 회로

- `assign`, `always_comb`: 입력이 달라지면 출력이 달라지는 조합 논리다. 자체적으로 클럭을 기다리지 않는다.
- `always_ff @(posedge clk)`: 상승 edge에서 레지스터를 갱신한다.
- `<=`: nonblocking assignment. 같은 edge의 다른 순차 블록은 원칙적으로 갱신 전 값을 읽는다.
- `=`: blocking assignment. 조합 계산이나 같은 블록의 임시 계산에 사용한다.
- `logic` 선언만으로 FF인지 LUT인지 결정되지 않는다. 사용 방식과 합성 결과가 결정한다.

예를 들어 `inputRegister <= inData;`와 `accumulator <= accumulator + inputRegister*w;`가
같은 edge에 실행되면, 누산에는 새 inData가 아니라 이전 inputRegister가 사용된다.
현재 코어의 capture/MAC 2단 구조가 이 성질을 사용한다.

### 14.2 parameter와 localparam

`parameter`는 상위 인스턴스에서 지정할 수 있는 합성 시 설정이다.
`localparam`은 그 설정에서 파생되는 내부 상수다. 실행 중 변경되는 레지스터가 아니다.

| 변수군 | 뜻 |
|---|---|
| `inChannels`, `outChannels` | 입력/출력 feature 채널 수 |
| `inHeight`, `inWidth` | 입력 feature의 공간 크기 |
| `kernelH`, `kernelW` | 커널 높이/너비 |
| `strideH/W`, `padH/W` | 커널 이동 간격/주변 zero padding 크기 |
| `tile` | 코어가 동시에 계산하는 출력 채널 수 |
| `inputLanes` | 입력 메모리 한 word에 묶인 채널 수; tile과 다른 개념 |
| `dataWidth`, `wWidth`, `bWidth` | 입력값/weight/bias 원소 비트 수 |
| `accWidth`, `actWidth` | 누산기/저장할 활성값 비트 수 |
| `biasShift`, `requantShift` | bias 정렬과 출력 스케일 축소에 필요한 shift |
| `inSigned` | 입력 원소를 signed로 해석할지 선택; weight는 signed |
| `parameterDir`, `wInitFile`, `bInitFile` | 합성·시뮬레이션 초기값 파일 경로 |

`$clog2(N)`은 N개 항목을 주소 지정하는 데 필요한 비트 수를 구할 때 사용한다.
N=1에서도 `[−1:0]` 같은 범위가 생기지 않도록 최소 1비트로 잡는 조건식이 많다.
주소 비트 수가 표현하는 모든 값이 유효한 것은 아니다. 예: 10비트는 0~1023을
표현하지만 입력 이미지의 유효 주소는 0~783뿐이다.

`8'(x)`는 8비트 크기 cast, `$signed(x)`는 signed 해석을 명시한다.
`'0`, `'1`은 대상 폭 전체를 0/1로 채운다. `{a,b}`는 비트 연결이고,
`word[lane*8+:8]`은 lane 시작 위치부터 8비트를 선택한다.

### 14.3 packed/unpacked 배열

```systemverilog
logic signed[tile-1:0][7:0] wdata; // packed: 한 덩어리 word로 취급 가능
logic[7:0] inData[0:tile-1];       // unpacked: 8비트 원소의 배열
```

같은 8개 값이라도 포트 타입과 packing 방식이 다르다. lane별 weight를 곱할 때
`$signed(weightRegister[lane])`를 명시하는 이유는 부분 선택 뒤의 부호 해석을
분명히 하기 위해서다. 전체 packed word가 signed라는 것만 믿고 계산하면 안 된다.

`for(genvar ...)`는 회로를 여러 개 생성한다. always 블록 안의 상수 범위 for도
일반 소프트웨어처럼 여러 클럭에 걸쳐 자동 실행되는 반복문이 아니다. 현재 lane
for문은 같은 edge에 여러 accumulator를 갱신하는 병렬 회로로 해석된다.

## 15. 소스 지도와 계층

합성 소스 목록은 `rtl.f`다. `.build` 내부에 생성된 netlist나 과거
`CNN_BRAM_XPM`의 동명 모듈을 함께 추가하면 중복 정의/버전 혼용 문제가 생긴다.

```text
mnistUartBRAMTOP
 ├─ serialPort : mnistUart
 └─ nn : mnistBRAMTOP
     ├─ imageMemory : mnistImageMEM
     ├─ maskGenerator : dropChannelMask
     ├─ conv1 : convTOP
     │   ├─ reader : convInputReader
     │   ├─ memory : convMEM
     │   ├─ core : convCore
     │   │   ├─ uRequant : requantUsign
     │   │   └─ pool : maxPool
     │   └─ outputMemory : xpm_memory_spram
     ├─ conv2 : convTOP（Conv1과 같은 구성, 파라미터가 다름）
     ├─ fcReader : fcInputReader
     ├─ fcMemory : convMEM
     ├─ classifier : fcCore
     └─ classify : argmax_pipe
```

현재 보드의 계층에는 `rngWord4`, `requantSign`, 독립 `relu`, 조합 `argmax`,
`sign` 인스턴스가 없다. 파일에 정의되어 있는 모듈과 실제 인스턴스화된 모듈은 구분해야 한다.

보드 top의 `rngSource : lutRngSource`에는13개 RO와 두 sng_lut가 있으며,
randomWord/randomValid를 nn의 maskGenerator로 전달한다.

## 16. mnistUart.sv — 변수와 RX/TX 상태

모듈 자체의 baud 기본값은 115200이지만, 보드 top이 baud=8,000,000으로
명시적으로 전달하므로 현재 비트스트림은 8Mbps다.

| 변수 | 용도 |
|---|---|
| `divisor`, `clockUnits`, `baudUnits` | gcd로 phase 단위 축소; 현재4000000,50,4 |
| `threshold` | clockUnits-baudUnits=46, bit tick 기준 |
| `phaseW` | phase 누산기 폭; 현재6bit |
| `rxMeta`, `rxSync` | 비동기 RX 핀의 1단/2단 동기화 FF, 초기값 1 |
| `rxState` | RX_IDLE/RX_START/RX_DATA/RX_STOP |
| `rxPhase`, `rxTick` | 수신 phase 및 bit 샘플 시점 |
| `rxIndex` | 현재 수신할 data bit 번호 0~7 |
| `rxShift` | 수신 중인 8비트 조립값 |
| `rxData` | 완료된 수신 바이트 |
| `rxValid`, `rxError` | stop bit 검사 후 각각 정상/오류의 1클럭 pulse |
| `txShift` | `{stop=1, data[7:0], start=0}`의 10비트 shift register |
| `txPhase`, `txTick` | 송신 phase 및 shift 시점 |
| `txIndex` | 전송 비트 번호 0~9 |
| `txBusy`, `txDone` | 전송 진행 level / 완료 pulse |

RX 상태 순서:

| 상태 | 동작 | 다음 상태 |
|---|---|---|
| RX_IDLE | 동기화된 rxSync가 0인지 확인 | RX_START |
| RX_START | 반 비트 대기 후 여전히 0인지 확인 | 1이면 IDLE, 0이면 DATA |
| RX_DATA | 한 비트 간격으로 rxShift[rxIndex]에 저장 | bit7 다음 STOP |
| RX_STOP | stop bit를 샘플; 1이면 valid, 0이면 error | IDLE |

TX는 별도 enum 없이 txBusy/txIndex로 진행한다. idle에서 txStart를 받으면
10비트 프레임을 로드하고 busy를 올린다. txTick마다 오른쪽으로 shift하고
최종 stop bit 기간이 끝나면 busy를 내리고 done을 1클럭 올린다.
코드에는 UART FIFO가 없다. RX가 바이트를 내보내면 상위가 해당 edge에서 소비해야 한다.

## 17. mnistUartBRAMTOP.sv — 변수와 패킷 FSM

| 변수 | 용도 |
|---|---|
| `resetSync[1:0]` | 외부 active-low resetN의 비동기 assertion/동기 해제용 FF |
| `rst` | resetSync 출력을 한 번 더 등록한 내부 synchronous reset |
| `timeoutCount`, `timeoutW` | 수신 중 바이트가 오지 않은 클럭 수와 그 폭 |
| `receiving` | HEADER1/COMMAND/PIXELS/CHECK_LO/CHECK_HI에서만 1 |
| `pixelIndex` | 다음 정규화 int8 쓰기 주소 0~783 |
| `imageSum` | command+pixels의16비트 합; 수신한 command 값으로 시작 |
| `checksumLow` | 수신한 checksum 하위 바이트 임시 저장 |
| `status` | 이번 패킷의 성공/오류 코드 |
| `replyIndex` | 송신할 응답 바이트 번호; 단일0~45, MC0~49 |
| `replySum` | 응답 status부터 마지막 score byte까지의 16비트 합 |
| `imgWriteEnable` | PIXELS이고 정상 rxValid와 imgReady가 모두 있을 때 1 |
| `txStart` | SEND_REQUEST이고 UART가 idle일 때 1 |
| `nnDone`, `nnBusy`, `resultValid` | CNN 완료 pulse, 실행 상태, 결과 보유 여부 |

| 상태 | 하는 일 / 전이 |
|---|---|
| HEADER0 | A5를 기다림. A5 수신 시 status를 0으로 하고 HEADER1 |
| HEADER1 | 5A면 COMMAND. A5가 다시 오면 계속 대기. 그 외는 HEADER0 |
| COMMAND | 03/04이면 pixelIndex=0, imageSum=command, mcRequest=(command==04) 후 PIXELS; 그 외 E4 |
| PIXELS | rxValid마다 현재 주소에 쓰고 checksum 누적; 마지막이면 CHECK_LO |
| CHECK_LO | checksumLow 저장 후 CHECK_HI |
| CHECK_HI | checksum, imgLoaded, imgLoadError 검사. 성공은 START_INFER, 실패는 E1 |
| START_INFER | CNN start를 한 클럭 전달하고 WAIT_INFER |
| WAIT_INFER | nnDone을 기다린 뒤 replyIndex/replySum 초기화 |
| SEND_REQUEST | 한 바이트를 UART에 요청하고 필요하면 replySum 누적 |
| SEND_WAIT | txDone 뒤 다음 바이트. MC 정상 응답의 마지막이면 iteration 증가 후 START_INFER; 49회차 완료 또는 오류이면 HEADER0 |

수신 중 framing error/timeout은 상태별 정상 처리보다 우선한다. timeout은
rxValid/rxError가 오거나 receiving이 아니면 0으로 초기화된다.
CNN 실행 중에는 수신 timeout을 세지 않으며 별도 inference watchdog도 현재 없다.

`mcRequest`는 이번 패킷의 MC 여부, `iteration[5:0]`은0~49 회차, `lastReplyByte`는45/49다.
`usedMask1/2`는 CNN이 사용한 mask, `randomWord[1:0]`은 두 LUT의 drop bit다.
MC 응답은 [패킷 표](MC50_LUT_OPERATION.md#명령과-응답)를 따른다.

단일 추론 응답 offset:

| offset | 내용 |
|---|---|
| 0, 1 | 5A, A5 |
| 2 | status |
| 3 | prediction 또는 FF |
| 4~7 | score[0], low byte first |
| 8~11 | score[1] |
| … | … |
| 40~43 | score[9] |
| 44, 45 | replySum low/high |

`(replyIndex-4)/4`는 클래스 번호, `((replyIndex-4)%4)*8`은 해당 score의
바이트 시작 위치다. 음수 score도 2의 보수 비트 그대로 전송하고 PC에서 signed32로 복원한다.

## 18. mnistBRAMTOP.sv — 한 회 추론 제어

| 변수/신호군 | 용도 |
|---|---|
| `acceptedStart` | IDLE && start && imgLoaded && !imgWriteEnable && !rst |
| `savedMC` | 시작 때 저장한 mcMode. 실행 중 외부 입력 변화와 분리 |
| `generatedMask1/2`, `maskBusy/Done` | mask 생성기의 출력과 상태 |
| `usedMask1/2` | savedMC가 1이면 생성 mask, 아니면 FF/FFFF |
| `imageRead*` | 이미지 BRAM → Conv1 연결 |
| `linkRead*` | Conv1 pooled BRAM → Conv2 연결 |
| `fcRead*` | Conv2 pooled BRAM → FC reader 연결 |
| `fcRequestIndex/Enable`, `fcInput/Valid` | FC logical scalar 요청/응답 |
| `fcWaddr/fcBaddr`, `fcWdata/fcBdata` | FC 파라미터 주소/데이터 |
| `busy1/2/FC`, `done1/2/FC` | 각 연산 블록의 실행 상태 |
| `maximumIndex/Valid` | argmax tree의 출력 |

상태는 다음과 같다.

```text
IDLE ─ deterministic ───────────────────┐
  └── MC → MASK_START → MASK_WAIT ──────┤
                                       ▼
START1 → WAIT1 → START2 → WAIT2 → START_FC → WAIT_FC
                                                    ↓
IDLE ← prediction/resultValid/done 갱신 ← WAIT_ARGMAX
```

START 상태들은 각각 1클럭이고 WAIT 상태는 해당 done을 기다린다.
`busy=(state!=IDLE)`, `imgReady=!busy && !start && !rst`다.
resultValid를 지우는 사건은 reset, 정상 이미지 쓰기, acceptedStart다.
scores는 FC 출력 레지스터라 resultValid=0인 동안 이전값/갱신 중 값이 보일 수 있다.
소비자는 resultValid 또는 done에 맞춰 읽어야 한다.

## 19. mnistImageMEM.sv — 쓰기 순서와 변수

| 변수 | 용도 |
|---|---|
| `writeData` | PC에서 정규화된 int8 비트패턴; XPM dina에 직접 연결 |
| `count` | 다음에 기대하는 순차 쓰기 주소 |
| `acceptedWrite` | reset/read 충돌 없이 주소 0 또는 올바른 다음 주소인지 검사 |
| `loaded` | 완전한 784바이트 이미지가 저장됨 |
| `loadError` | 쓰기 순서/조건 위반 기록 |
| `readRequest` | 유효 범위의 readEnable이며 동시 쓰기/reset이 없음 |
| `validPipeline[1:0]` | 읽기 응답의 유효 시점 |
| `memoryData` | XPM 출력 |

첫 주소 0은 이전 loaded 상태와 무관하게 새 로드를 시작할 수 있다.
잘못된 쓰기를 시도하면 loadError=1, loaded=0, count=0이 된다.
마지막 정상 주소 783을 쓴 edge에서 loaded=1이 된다.
BRAM 자체를 reset으로 모두 0으로 채우지 않는다. 제어 상태를 초기화하고
새 이미지 전체 쓰기를 요구하여 이전 contents를 유효 데이터로 취급하지 않는다.

mnistImageMEM은 normalizeFile 파라미터나 정규화 ROM을 갖지 않는다.
입력의 스케일/부호는 PC와 Conv1의 계약이며 메모리는8비트를 그대로 저장한다.

## 20. convMEM.sv — weight/bias BRAM 배치

| 변수/파라미터 | 의미 |
|---|---|
| `numTile` | outChannels/tile |
| `kernelTerms` | inChannels×kernelH×kernelW |
| `wDepth` | numTile×kernelTerms |
| `wWordWidth`, `bWordWidth` | tile×원소 비트 수 |
| `bMemoryDepth` | bias word 수; XPM 최소 조건 때문에 최소 2 |
| `weightWord`, `biasWord` | XPM이 반환하는 packed word |
| `waddr`, `baddr` | weight term word / output tile bias word 주소 |

weight 주소는 `outputTile*kernelTerms + term`이다. 한 word는 그 term에 대한
서로 다른 출력 채널 tile개 weight를 담는다. bias는 tile마다 한 word다.
각 lane은 낮은 비트부터 차례로 배치된다.

| 메모리 | word 수 × 비트 |
|---|---:|
| conv1_w | 9×64 |
| conv1_b | 2×64 (실제 tile 1개, 남는 word는 padding) |
| conv2_w | 144×64 |
| conv2_b | 2×64 |
| classifier_w | 1568×40 |
| classifier_b | 2×40 |

XPM의 ena=1, wea=0으로 연결되어 실행 중에는 읽기 전용이다.
`.mem`은 초기값으로 bitstream에 반영된다. 현재 UART에는 weight 업데이트 명령이 없으므로
PC에서 `.mem` 텍스트만 수정한다고 이미 프로그램된 보드의 가중치가 바뀌지 않는다.

## 21. convInputReader.sv — 모든 핵심 변수와 계산 예제

### 21.1 서로 다른 좌표

| 이름 | 좌표계 |
|---|---|
| `requestRow/Column` | 지금 계산하려는 Conv 출력의 위치 |
| kernel row/column | 커널 내부의 상대 위치. 별도 이름의 레지스터가 아니라 decodedTerm의 필드 |
| `inputRow/Column` | 실제로 읽을 입력 feature의 좌표; padding이면 음수/범위 밖 가능 |
| `requestTerm` | 입력 채널·커널 row·커널 column을 한 번호로 펼친 것 |

3×3에서 kernelRow는 항상 0~2지만 inputRow는 커널이 놓인 위치에 따라 변한다.
출력 row=5에서는 inputRow가 4,5,6이고, 출력 row=6에서는 5,6,7이다.

### 21.2 폭과 lookup 변수

| 변수 | 용도 |
|---|---|
| `termIdxW` | 전체 kernel term을 표현하는 비트 폭 |
| `rowW/colW` | 출력 좌표의 폭 |
| `memoryDepth/addrW` | 입력 packed BRAM의 word 수/주소 폭 |
| `laneW`, `channelW` | lane 번호/입력 채널 번호 폭 |
| `kernelRowW/kernelColW` | 커널 내부 좌표 폭 |
| `decodeW` | channelW+kernelRowW+kernelColW |
| `termLookup` | term → {channel, kernelRow, kernelColumn} 상수 표 |
| `decodedTerm` | 현재 요청 term의 조회값 |
| `inputChannel/Row/Column` | 조합 계산의 정수 임시 변수 |
| `requestPadding` | inputRow/Column이 입력 범위를 벗어났는지 |
| `validPipeline` | requestEnable의 2단 지연 |
| `paddingPipeline` | requestPadding의 2단 지연 |
| `lanePipeline[0:1]` | 응답과 함께 사용할 lane 번호 지연 |

초기 표는 아래 상수 식으로 생성된다.

```text
channel = t / (kernelH*kernelW)
kernelRow = (t/kernelW) % kernelH
kernelColumn = t % kernelW
```

`initial for`에서 상수별로 표를 만드는 나눗셈은 실행 중 입력에 따라 나누는
회로와 다르다. `rom_style="distributed"`는 이 작은 표를 LUT ROM으로
구현하려는 합성 의도다. 현재 읽기는 조합식이며 속성만으로 읽기 latency가
추가되거나 BRAM의 synchronous read 계약이 자동 충족되지는 않는다.

표의 크기는 입력 채널 8개에서 1×1이면 8, 3×3이면 72, 5×5이면 200,
3×5이면 120 항목이다. 따라서 reader는 여러 크기에 대응하도록 작성됐지만,
현재 상위 네트워크/weight/검증은 3×3에 맞춰져 있다. 크기 변경은 재합성뿐 아니라
차원과 가중치 순서 검증이 필요하며 dilation은 현재 주소식에서 지원하지 않는다.

### 21.3 요청 한 개의 계산

Conv2에서 requestRow=5, requestColumn=7, requestTerm=31:

```text
inputChannel = 31/9 = 3
kernelRow = (31/3)%3 = 1
kernelColumn = 31%3 = 1
inputRow = 5*1+1-1 = 5
inputColumn = 7*1+1-1 = 7
readAddress = (3/8)*14*14 + 5*14 + 7 = 77
lane = 3%8 = 3
```

주소77의 64비트 word를 읽고 lane3을 선택하여 outData[0]으로 내보낸다.
입력 단일 scalar를 출력 8개 MAC이 공유한다. 출력 채널 번호는 reader에 필요 없다.

### 21.4 padding과 valid

`readEnable=requestEnable && !requestPadding && !rst`다. padding은 BRAM을
읽지 않지만 validPipeline에는 요청을 넣어 정상 요청과 동일한 시점에 0을 반환한다.
outValid는 readValid를 그대로 복사하지 않는다. padding에도 응답이 필요하기 때문이다.
실제 메모리 응답 지연은 고정 2클럭을 전제로 하며, non-padding outValid에
readValid가 없으면 시뮬레이션 assertion이 실패한다. 가변 지연이나 backpressure는 지원하지 않는다.

## 22. convTOP.sv — reader/core/ROM과 feature RAM 연결

| 신호 | 용도 |
|---|---|
| `coreStart` | start && !busy && !rst |
| `requestEnable/Term/Row/Column` | core → reader |
| `inputValid/inputData` | reader → core |
| `waddr/baddr/wdata/bdata` | core ↔ parameter ROM |
| `outWriteEnable/Address/outData` | core의 pooled 출력 |
| `writeWord/readWord` | feature 메모리에 쓰고 읽는 64비트 packed 값 |
| `writeRequest` | outWriteEnable && !rst |
| `readRequest` | idle이고 start/write/reset이 없으며 주소 유효할 때 읽기 수락 |
| `memoryAddress` | 쓰기면 outWriteAddress, 아니면 readAddress |
| `readValidPipeline` | 수락된 읽기에 대한 응답 valid |

한 feature 메모리는 single-port다. 연산 중에는 core가 쓰고, 끝난 뒤 다음
레이어가 읽는다. 이 일정이 read/write 충돌을 피하게 한다. 다른 레이어의 요청이
busy 중 도착하면 조용히 대기시키지 않고 시뮬레이션에서 잘못된 요청으로 잡는다.
동시 read/write가 필요해지면 이 계약이나 메모리 포트 구조를 변경해야 한다.

## 23. convCore.sv — 누산 변수, FSM, 시간 관계

### 23.1 핵심 레지스터

| 변수 | 의미 |
|---|---|
| `tileIndex` | 현재 처리하는 출력 채널 묶음 |
| `outputRow/Column` | pooling 전 Conv 출력 위치 |
| `weightBaseAddress` | 현재 tile weight의 시작 주소 |
| `issueTerm` | 다음에 요청할 입력/weight 항 번호 |
| `consumeTerm` | 응답 capture 중인 항 번호 |
| `issueDone` | 현재 출력 위치의 모든 term을 요청했는지 |
| `weightValid[1:0]` | weight read 요청의 2단 지연 |
| `inputRegister/weightRegister` | 지연을 맞춘 입력/weight 피연산자 |
| `macValid/macLast` | 등록된 피연산자가 유효한지 / 마지막 term인지 |
| `biasValue[lane]` | sign extend와 biasShift를 적용한 bias |
| `accumulator[lane]` | 현재 출력 위치에 대한 32비트 누산 |
| `channelMaskLatched` | start에서 고정한 출력 채널 mask |
| `quantizedData` | 누산값을 ReLU/shift/포화한 조합 출력 |
| `convData/convValid` | mask까지 적용해 pooling으로 보내는 등록된 값/유효 pulse |
| `poolData/Valid/Done` | pooling의 값/출력 유효/마지막 입력 처리 완료 |
| `poolRow/Column` | BRAM에 쓸 pooling 결과의 공간 좌표 |
| `inputValue`, `weightValue`, `product` | signed 확장 및 MAC 계산용 임시값 |

### 23.2 상태별 동작

| 상태 | 로직 |
|---|---|
| IDLE | start 수락 시 mask 저장, tile/좌표/주소 초기화, busy=1 |
| BIAS_REQ | tile의 bias 주소 설정, pooling 시작 및 출력 좌표 초기화 |
| BIAS_WAIT0/1 | bias ROM의 지연을 기다림 |
| BIAS_LOAD | bdata를 sign extend한 뒤 biasShift만큼 왼쪽 shift하여 저장 |
| PIXEL_INIT | 모든 lane accumulator=biasValue; term/valid 제어 초기화 |
| WEIGHT_RUN | 입력/weight를 연속 요청, 도착한 값을 capture, 이전 capture를 MAC |
| WRITE_OUTPUT | requantizedData에 mask를 적용해 convData로 등록; 다음 위치 선택 |
| WAIT_POOL | 마지막 pooled write 완료까지 기다린 뒤 다음 tile 또는 done |

요청 완료와 연산 완료는 다르다. issueDone이 1이어도 BRAM에서 오고 있는
데이터와 capture된 마지막 MAC이 남아 있다. macLast가 실제로 누산되는
edge에 WRITE_OUTPUT으로 넘어가므로 마지막 곱셈이 빠지지 않는다.

### 23.3 파이프라인 edge를 읽는 방법

실제 파형에서는 edge 전/후와 다른 always_ff가 읽는 값을 구분해야 한다.
E0에서 요청을 샘플했다고 할 때 현재 XPM/valid/capture 연결은 다음처럼 읽는다.

| 시점 | 해당 요청의 진행 |
|---|---|
| E0 | XPM이 주소/enable 샘플, valid 첫 단에 요청 저장 |
| E1 이후 | 2단 읽기 출력과 valid 마지막 단에 해당 응답이 나타남 |
| E2 | core가 edge 직전의 응답/valid를 읽어 operand register에 capture |
| E3 | 이전 edge에서 capture한 피연산자를 MAC |

요청/응답을 단순히 같은 edge의 새 값으로 읽으면 한 클럭씩 혼동하기 쉽다.
BRAM READ_LATENCY_A=2와 core의 별도 operand register/MAC 단계를 함께 봐야 한다.
연속 요청에서는 여러 term이 각 단계에 동시에 걸쳐 있다.

### 23.4 signed 연산

입력은 dataWidth보다 한 비트 넓게 확장한다. signed 입력은 부호를 복제하고,
unsigned 입력은 앞에 0을 붙여 signed 곱셈에서도 128~255가 음수가 되지 않게 한다.
8비트 입력과 weight에서 productWidth=8+1+8=17이다. 좁은 곱셈 결과를 만든 뒤
accWidth로 확장해 더한다. 일반적인 무한 정밀도 정수와 달리 RTL 누산은 폭을
넘으면 wrap할 수 있다. 현재 차원의 보수적 범위는 32비트 안이지만 큰 모델로
바꿀 때는 새 overflow 검사가 필요하다.

## 24. maxPool.sv — 공간 이력과 유효 window

| 변수 | 역할 |
|---|---|
| `rowIndex/columnIndex` | 들어오는 Conv feature의 위치; inValid일 때만 증가 |
| `historySize` | kernelSize−1, 배열 선언을 위해 최소1 |
| `previousRow` | 채널별 앞선 행의 값 |
| `leftVerticalMax` | 앞선 열에서 계산한 세로 최대값 |
| `verticalMax` | 현재 열의 kernelSize개 행에 대한 최대값 |
| `windowMax` | 세로 최대값들을 가로로 비교한 최종 window 최대값 |
| `windowValid` | window가 완성됐고 stride 위치에 해당하는지 |
| `outValid/outData` | 유효 pooling 출력 pulse/값 |
| `done` | 해당 tile의 마지막 입력 위치를 처리했을 때 pulse |

2×2에서 (row=1,col=1)이 첫 유효 window이고 그다음 col=3,5,…에서 출력한다.
첫 행/열에서는 이력을 채우며 아직 값을 내보내지 않는다. 따라서 메모리 이력
전체를 reset으로 초기화할 필요가 없다. outValid와 done은 같은 edge에 올라갈
수 있으며 상위는 마지막 pooled write를 놓치지 않도록 WAIT_POOL에서 마무리한다.
이 모듈은 unsigned 비교다. 현재 ReLU 이후이므로 맞지만 signed feature를 직접
pooling하도록 바꾸면 비교 의미부터 검토해야 한다.

## 25. fcInputReader.sv와 fcCore.sv

### 25.1 채널 우선 flatten 복원

`area=inHeight*inWidth=49`, `inNum=784`다. logical index i에 대해:

```text
channel = i/49
position = i%49
word = (channel/8)*49 + position
lane = channel%8
```

| i | 의미 | word/lane |
|---:|---|---|
| 0 | 채널0, 위치0 | 0/0 |
| 48 | 채널0, 위치48 | 48/0 |
| 49 | 채널1, 위치0 | 0/1 |
| 392 | 채널8, 위치0 | 49/0 |
| 783 | 채널15, 위치48 | 97/7 |

`addressLookup`은 위 word/lane을 저장한 distributed ROM이다.
`decodedAddress`를 쪼개 readAddress와 lanePipeline에 넣고 validPipeline과
함께 지연시켜 올바른 scalar를 반환한다. Conv reader와 달리 padding은 없다.

### 25.2 FC 변수와 상태

| 변수 | 의미 |
|---|---|
| `numTile/tileW` | 출력 class tile 수/그 인덱스 폭 |
| `issueIdx/consumeIdx` | 입력 항 요청/응답 번호 0~783 |
| `tileIndex` | 클래스0~4이면 0, 5~9이면 1 |
| `wbaseAddr` | tile0=0, tile1=784 |
| `wvalid`, `issueDone` | 요청 지연과 모든 요청 완료 여부 |
| `inputRegister/weightRegister` | BRAM 응답 capture |
| `macValid/macLast` | capture된 항의 유효/마지막 여부 |
| `accumulator[0:4]` | 현재 5개 클래스의 누산값 |
| `productExtend` | 좁은 signed product를 accWidth로 확장한 값 |
| `outData[0:9]` | 완성된 클래스 점수 레지스터 |

```text
IDLE → BIAS_REQ → BIAS_WAIT0 → BIAS_WAIT1 → BIAS_LOAD
     → W_RUN → WRITE_RESULT
                    ├─ 다음 tile → BIAS_REQ
                    └─ 마지막 tile → FINISH → IDLE
```

BIAS_LOAD가 bias로 accumulator를 초기화한다. W_RUN의 capture/MAC는 Conv와
같은 원리다. WRITE_RESULT는 tileIndex*5+lane에 누산 결과를 기록한다.
FINISH에서 busy를 내리고 done을 올린다. FC 뒤에는 ReLU나 unsigned 포화가 없다.
두 tile이 각각 784개 입력을 요청하므로 한 추론의 FC logical read 요청은 1568회다.

## 26. requantize.sv와 functions.sv

### 26.1 사용 중인 requantUsign

`inElement`는 한 lane의 누산값, `shifted`는 ReLU/shift 후 값,
`clipped`는 outWidth 범위로 포화한 값이다. 양수 a에 대해:

```text
q = (a + 2^(shift-1)) >> shift
out = min(q, 2^outWidth-1)
```

0 이하의 값은 0이다. 양수의 반올림은 half-up이다. weight/bias/input LUT
생성에 사용한 ties-to-even과 구분해야 한다. 현재 shift=7/8은 정상 사용 범위다.
이 구현을 shift=0 또는 음수에 그대로 일반화해서 쓰면 안 된다.

### 26.2 미사용 requantSign의 알려진 문제

`shiftRound`는 부호를 고려한 반올림을 의도하고, `postiveShift`(원문 철자),
`roundValue`, `outMin/outMax`는 범위와 반올림 상수다. 그러나 현재 선언의
outMax는 양수 최댓값이 아니라 0으로 만들어져 있다. 이 모듈은 현재 datapath에
인스턴스화되어 있지 않으므로 검증된 CNN 결과에는 사용되지 않았다.
signed 재양자화에 재사용하기 전 반드시 수정·검증해야 한다. 문서 작성 중에는 RTL을 수정하지 않았다.

### 26.3 argmax_pipe와 다른 보조 모듈

`argmax_pipe`의 `stageCount=$clog2(number)=4`이고,
`maxValue[level][node]`, `maxIndex[level][node]`가 각 비교 단계의 후보를 저장한다.
`validPipeline`은 해당 후보가 유효한지 추적한다. 홀수 개 후보에서 짝이 없는
마지막 후보도 레지스터 한 단을 통과시켜 latency를 맞춘다.
오른쪽 값이 엄격히 큰 경우에만 선택하므로 동점은 작은 인덱스가 이긴다.

`relu`는 음수면0, `argmax`는 조합 선형 비교, `sign`은 signed 입력이 0보다
크면1을 출력하는 보조 모듈이다. sign은 부호비트를 그대로 내보내는 모듈이 아니다.
세 모듈은 현재 보드 계층에 직접 사용되지 않는다.

## 27. dropChannelMask.sv — 난수와 채널 마스크

| 변수 | 의미 |
|---|---|
| `index/indexWidth` | 채널0부터 channels1+channels2−1까지 채울 위치/폭 |
| `mask1/mask2` | 1=keep, 0=drop |
| `busy/done` | 마스크 생성 진행 level / 완성 pulse |
| `randomReady` | busy && !rst; 다음 난수 word를 받을 수 있음 |
| `randomWord/randomValid` | 외부가 제공한 4비트 값과 유효 신호 |

보드에서는 `useLutBits=1`이다. busy && randomValid마다 한 채널을 채운다.
Conv1은 !randomWord[0], Conv2는 !randomWord[1]을 저장한다.
4비트 값의 크기로 rejection하지 않는다.24채널 이후 done을 올린다.

코어 기본값 `useLutBits=0`은 외부 균등 난수 입력용 decimal 모드다.
이 모드에서는 start 수락 시 mask를 모두1로 초기화하고 index=0부터 채운다.
busy && randomValid && randomWord<10인 edge에서만 index를 증가시킨다.
10~15는 거절하고 동일 채널용 다음 word를 기다린다. randomWord=0은 두 레이어
모두 drop, 1은 Conv1 keep/Conv2 drop, 2~9는 둘 다 keep이다.
24개 채널을 채우면 done pulse와 함께 busy=0이 된다.

이 방식의 정확한 0.1/0.2 확률은 입력 word의 균등성에 의존한다. 연속 word의
상관관계도 MC 품질에 영향을 준다. 입력이 계속 10~15이거나 valid가 없으면
완료하지 않는다. 현재 mask 생성기에는 watchdog이 없다.

`rngWord4`의 `samples`는 rawBit shift register, `count`는 0~3 counter다.
4번째 샘플에서 `{samples[2:0],rawBit}`를 randomWord로 내고 randomValid를
한 클럭 올린다. ready 입력이 없으므로 소비하지 않은 word는 유실될 수 있다.
rawBit 입력을 동기화하거나 편향을 제거하는 회로는 이 adapter에 포함되어 있지 않다.

## 28. 클럭, reset, XDC와 실물 상태

현재 핀은 clk=E3, resetN=C12, uartRX=C4, uartTX=D4다.
LD0~LD7은 H17/K15/J13/N14/R18/V17/U17/U16이며 LVCMOS33이다.
`create_clock -period 10.000`이 100MHz 내부 타이밍 목표를 설정한다.

외부 resetN이 내려가면 resetSync는 비동기로11이 되지만 내부 rst는 clk에서
등록된다. resetN이 올라가면 두 단계 shift 후 rst 레지스터를 거쳐 내부 reset이
해제된다. 내부 연산 블록들은 synchronous reset을 사용한다.
매 이미지/iteration마다 전체 시스템 reset을 걸지 않고 각 모듈 start/FSM으로 다시 실행한다.

false path는 RX 핀→첫 동기화 FF, 외부 reset→reset synchronizer,
RO→sampleMeta의 비동기 샘플링 입력으로 제한한다.
내부 CNN 연산 경로 전체를 false path로 숨기는 제약은 없다. UART/LED는
boardClock과 동기된 외부 수신 클럭이 없으므로 register-to-pin 전파 지연에
10ns 예산을 둔다. 이 값은 UART 비트 주기 1us와 다르다.

이전 단일추론 MCDC build: WNS +0.058ns, WHS +0.051ns, LUT 5276, FF 5421,
BRAM tile10, DSP0. setup 여유가 작으므로 RTL이나 제약을 변경한 후에는
다시 구현·검증해야 한다. DRC REQP-1840 3개는 FC bias ROM에 삽입된 enable
gating과 reset 경로에 관한 경고이며 기존 보고서에 분석을 남겼다. warning-free라고 해석하지 않는다.

JTAG로 bitstream을 프로그램한 상태는 휘발성이다. 현재 작업은 구성 flash를
기록하지 않았으므로 전원을 껐다 켜면 다시 해당 bitstream을 로드해야 한다.

## 29. Python과 생성/실행 스크립트

### 29.1 모델 변환

`export_mcdc.py`는 제공된 .pt의 연속 float32 tensor를 제한된 pickle reader로
읽고 Q7 양자화를 적용한다. `packed()`는 output tile/term/lane 순으로
weight word를 생성한다. bias 최소 word padding을 포함하고, 생성 word를 다시
풀어 원본 양자화 tensor와 같은지 검사한다. normalize LUT와 6개 golden vector도 생성한다.
실수 activation 비교는 NumPy reference이며 학습 PyTorch 프로그램을 직접 실행한 결과와 구분한다.

### 29.2 board_client.py

| 함수/클래스 | 역할 |
|---|---|
| `ports()` | 사용 가능한 COM 포트 목록 |
| `load_mnist()` | 공개 test split 다운로드/MD5/IDX header 검증 및 배열 생성 |
| `make_packet()` | uint8 입력은 PC 정규화, 이미 int8이면 그대로789바이트 패킷으로 조립 |
| `decode_reply()` | 46바이트 길이/header/checksum/status/예측 일관성 검사, signed score 복원 |
| `Board.__init__()` | 8Mbps 8N1 포트를 열고 이전 불완전 요청의 timeout을 기다린 후 잔여 RX 제거 |
| `Board.infer()` | 요청1개 전송, 응답46바이트를 모아 검사하고 왕복 시간 반환 |
| `Board.close()` | 포트 해제; context manager에서 자동 실행 |
| `Reference` | 실제 .mem을 unpack하여 동일 정수 Conv/pool/FC를 수행 |

`Board.infer()`의 응답 수집 deadline은 요청 시작 기준3초이며 serial read timeout은
0.1초다. 짧게 읽혔다고 완성 패킷으로 취급하지 않고 누적한다. 오류 시 다음
이미지를 자동 재전송하지 않는다. Reference.infer(image, mask1, mask2)는 전달된 mask로 동일한 정수 연산을 수행한다.
Board.infer_mc()는 command04로 입력을 한 번 보내고50개 응답의 checksum/회차/점수를 검사한다.
board_mc_cli.py는 MNIST900+KMNIST50+Fashion50을 실행하고 PC에서 최종 결과를 계산한다.
mc_metrics.py는 안정적인 softmax, entropy, MI, OOD AUROC를 계산한다.

### 29.3 board_mc_cli.py

MC50 평가 진입점이다. 기본900 MNIST+50 KMNIST+50 Fashion을 선택하고,
PC에서 정규화한 이미지마다50회 FPGA 점수를 수신한다. mc_metrics.py에서
softmax 평균·entropy·MI를 계산한다. --verify-scores는 반환 mask를 사용한
Python 정수 CNN과 각 회차 점수를 비교한다. 결과 CSV/NPZ/JSON을 저장한다.

```bat
python scripts/board_mc_cli.py --port COM6 --verify-scores
```

## 30. 검증 범위

현재8Mbps/PC 정규화 버전의 Python·RTL·실물 검증 결과는
[검증 기록](INT8_8MBPS_VALIDATION.md)에 정리되어 있다.
1000개 이미지,총50000회 추론의500000개 점수가 같은 mask를 적용한
Python 정수 기준과 일치했다. 모델 분류 정확도와 하드웨어 점수 일치는
서로 다른 검사다.

## 31. 구조를 수정할 때 함께 봐야 하는 부분

| 수정 대상 | 함께 맞출 부분 |
|---|---|
| kernelH/W | reader term 수/폭, weight ROM depth/order, core 루프, padding, 다음 레이어 차원 |
| 입력/출력 채널 수 | mask 폭, tile 수, feature RAM depth, FC input 수, weight 파일 |
| Conv tile/FC tile | packed word 폭, ROM layout, reader inputLanes, 상위의 고정 tile 제약 |
| pooling/stride/padding | 출력 H/W, feature 주소, FC flatten 길이, golden vector |
| BRAM read latency | reader valid/lane/padding, core weightValid와 capture 시점 |
| 정수 비트 폭/shift | 부호 확장, accumulator 범위, bias 스케일, UART score 해석, Python reference |
| UART 모듈/baud | handshake pulse, RX 동기화, XDC 경로명, PC baud, serial test |
| MC50 | 이미지 보존,50회 start/done, SNG 유효성, 응답회차/마스크/점수, PC softmax 스케일 |

개별 모듈이 파라미터를 갖는다고 보드 전체가 모든 조합을 자동 지원하는 것은
아니다. 현재 mnistBRAMTOP은 Conv tile8/FC tile5를 요구하고 채널과 feature
연결 폭도 현재 네트워크에 맞춰 선언되어 있다. 커널만 바꾸더라도 이 연결들을
검토해야 한다. 변경 후 기존 golden 데이터가 새 구조의 정답일 것이라고 가정하지 않는다.

## 32. 용어와 디버깅 관찰 순서

| 용어 | 이 프로젝트에서 뜻 |
|---|---|
| channel | 서로 다른 feature map. row/column과 다른 차원 |
| kernel term | 한 출력 누산에 사용하는 입력채널×커널위치의 항 |
| tile | 동시에 처리하는 출력 채널 묶음 |
| lane | 한 묶음/word 내부의 원소 자리 |
| feature | Conv/pooling 후의 중간 활성값 |
| word/address | 한 번에 읽는 메모리 묶음/그 묶음의 번호; byte와 다를 수 있음 |
| MAC | multiply-accumulate, 곱해서 누적 |
| valid | 지금의 데이터가 유효하다는 표시; ready와 다름 |
| ready | 새 입력을 받을 수 있음 |
| busy | 작업 진행 중이라는 level |
| done | 완료 사건을 나타내는 pulse |
| logit | softmax 이전 클래스 점수 |
| mask | 채널 값을 유지/0으로 만들지 결정하는 비트 |

파형을 볼 때는 다음 순서로 원인을 좁힐 수 있다.

1. `serialPort.rxValid/rxData`: 바이트 자체가 올바르게 복원되는가?
2. top의 `state/pixelIndex/imageSum/status`: 완전한 패킷으로 받아들였는가?
3. `nn.imgLoaded/acceptedStart`: 이미지 로드와 추론 시작 조건을 충족했는가?
4. reader의 `requestTerm/decodedTerm/inputRow/inputColumn/readAddress`: 읽을 위치가 맞는가?
5. `weightValid/inValid/inputRegister/weightRegister/macValid`: 같은 항의 데이터가 정렬됐는가?
6. `accumulator/quantizedData/convData`: 수치 스케일과 mask가 맞는가?
7. `poolValid/outWriteAddress/writeWord`: pooling 순서와 feature packing이 맞는가?
8. FC의 `requestIndex/readAddress/lanePipeline/outData`: flatten 순서가 맞는가?
9. `maximumValid/prediction/nnDone/replyIndex/txData`: 완료와 응답이 올바르게 이어지는가?

현재 bitstream에는 ILA/VIO가 없으므로 Vivado Hardware Manager에서 이 내부
파형이 자동으로 보이지 않는다. 위 신호는 시뮬레이션에서 관찰하거나 ILA를
추가한 별도 구현으로 캡처해야 한다. UART CLI는 외부 입출력을 검증하는 경로다.

## 소스와 검증 기록 바로 열기

### RTL

- [requantize.sv](../rtl/requantize.sv)
- [functions.sv](../rtl/functions.sv)
- [convMEM.sv](../rtl/convMEM.sv)
- [maxPool.sv](../rtl/maxPool.sv)
- [dropChannelMask.sv](../rtl/dropChannelMask.sv)
- [mnistImageMEM.sv](../rtl/mnistImageMEM.sv)
- [convInputReader.sv](../rtl/convInputReader.sv)
- [convCore.sv](../rtl/convCore.sv)
- [convTOP.sv](../rtl/convTOP.sv)
- [fcInputReader.sv](../rtl/fcInputReader.sv)
- [fcCore.sv](../rtl/fcCore.sv)
- [mnistBRAMTOP.sv](../rtl/mnistBRAMTOP.sv)
- [mnistUart.sv](../rtl/mnistUart.sv)
- [mnistUartBRAMTOP.sv](../rtl/mnistUartBRAMTOP.sv)

### PC 및 문서

- [MC50 평가](../scripts/board_mc_cli.py)
- [UART 및 정수 기준 모델](../scripts/board_client.py)
- [메모리 추출](../scripts/export_mcdc.py)
- [불확실성 지표](../scripts/mc_metrics.py)
- [데이터 준비](../scripts/ood_data.py)
- [PC 정규화와8Mbps](HOST_NORMALIZE_8MBPS.md)
- [MC50 동작](MC50_LUT_OPERATION.md)
- [현재 검증 기록](INT8_8MBPS_VALIDATION.md)
