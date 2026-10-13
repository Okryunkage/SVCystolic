> 소스 배포본: 실행 순서는 [README](../README.md)를 따른다. 검증 수치는 기존 개발본의 기록이며, 빌드·평가 결과 파일은 포함하지 않는다. 이 폴더의 export_mcdc.py는 모델 메모리와 CPU 정규화 표만 생성하고 시뮬레이션 fixture는 생성하지 않는다.

# PC 정규화와 UART8Mbps

## 입력 데이터 경로

```text
원본 uint8 이미지 → PC normalize_image() → signed int8의 원래8비트
  → UART8Mbps → FPGA 입력 BRAM에 그대로 저장 → CNN50회 → PC uncertainty
```

`board_client.py`의 normalize_image()는 float32로 아래 식을 계산한다.

```text
x = pixel / float32(255)
x = (x - float32(0.1307)) / float32(0.3081)
q = int8(clip(rint(x * float32(32)), -128, 127))
```

rint는 가장 가까운 정수로 반올림하고 정확한 동점은 짝수로 처리한다.
원본 픽셀0/128/255는 각각-14/39/90이 된다. int8의2의 보수 비트를 그대로
전송하며 추가 encoding이나 부호 바이트는 없다. -14는0xF2로 전송한다.
checksum에는 signed 수치-14가 아니라 전송 byte값242를 더한다.

make_packet(image)는28×28 uint8 입력이면 PC에서 정규화한다. 이미 정규화된
np.int8 배열이면 추가 정규화 없이 그대로 전송한다. 원본 uint8를 단순히
astype(int8)로 바꾸는 것은 정규화가 아니다. MNIST/KMNIST/Fashion 모두 동일한
전처리를 적용한다. 이미지 전송량은784바이트, 요청 패킷은789바이트다.

FPGA mnistImageMEM에는 normalizeTable과 $readmemh가 없다. XPM의 dina에는
writeData를 직접 연결한다. 메모리는784×8bit, 주소 폭10bit이고 Conv1은
이 비트패턴을 signed 입력으로 해석한다. 이미지 수신 때 한 번 저장하고50회 재사용한다.
Feature 메모리는64bit×196word와64bit×98word로 동일하다.

normalize.mem은 export_mcdc.py가 생성하는 CPU reference/회귀 테스트용 표로
남는다. Python의 직접 계산을256개 모든 입력에서 이 표와 비교한다.
실제 Python 송신 경로는 파일을 읽지 않고 식을 계산하며, 합성된 FPGA에도
정규화 ROM은 없다. 가중치와 bias .mem 및 CNN 정수 스케일은 그대로다.

## UART와 명령

100MHz 클럭에서8Mbps는 비트당12.5클럭이다. mnistUart는 고정13클럭으로
반올림하지 않고 phase 누산기로12/13클럭 간격을 생성한다. 평균 bit 시간125ns,
8N1 한 프레임10bit 시간1.25us다. TX handshake 때문에 바이트 사이 idle 시간이
더해질 수 있다. RX는 동기화된 입력의 start 중앙을 확인한 뒤 같은 fractional
간격으로 data/stop 중앙을 샘플한다.

clockHz와 baud의 최대공약수로 phase 단위를 줄인다. 현재 clockUnits=50,
baudUnits=4, threshold=46이다. 매 clk마다4를 더하고, 기존 phase>=46이면
bit tick을 발생시키면서46을 뺀다. RX 시작 phase는25여서 첫 tick은 반 비트
대기 이후 발생한다. TX는0부터 시작해10bit를125클럭에 전송한다.

| 명령 | 입력 | 응답 |
|---|---|---|
| 03 | 정규화된 int8×784 | 단일추론, 기존46바이트 응답 |
| 04 | 정규화된 int8×784 | MC50, 기존50바이트 응답×50개 |

요청은 A5 5A command payload sum16LE다. 합은 command+784개 전송 byte값의
하위16비트다. 응답 형식은 [MC50 설명](MC50_LUT_OPERATION.md#명령과-응답)을 따른다.
이전 raw uint8 명령01/02는 E4로 거절한다. 이전1Mbps 비트스트림과 새 Python을
섞어 사용하지 않는다. 호환되지 않는 입력 의미가 조용히 처리되지 않도록 명령을 구분한다.

8Mbps에서 요청789바이트의 순수 wire 시간은0.98625ms, MC 응답2500바이트는
3.125ms다. CNN 계산·송신 사이 idle·USB·Python 처리 시간이 추가되므로 전체
추론 시간이8배 줄어드는 것은 아니다. 보드와 PC 양쪽 모두8Mbps로 설정한다.

## 실행

새 비트스트림: `output/nexys_a7_mc50_int8_8mbps/mnist_uart_mc50_int8_8mbps.bit`.
Vivado Hardware Manager의 Program Device로 이 파일을 적용한다.

```bat
cd /d C:\Users\user\Desktop\gpt\CNN_MC50_Source\scripts
python board_mc_cli.py --port COM6 --verify-scores
```

기본900MNIST+50KMNIST+50Fashion, 이미지당50회, UART8Mbps다.
평가 프로그램 board_mc_cli.py의 기본 baud는8000000이다.
결과 CSV/NPZ/JSON은 output/mc50_runs의 새 폴더에 저장한다.
Python 환경에는 numpy와 pyserial이 필요하다. 기존 명령행 사용법은 동일하고
입력 정규화는 클라이언트 내부에서 수행된다.

## 검증

검증 기록과 실제 측정치는 [8Mbps 검증 기록](INT8_8MBPS_VALIDATION.md)에 있다.
