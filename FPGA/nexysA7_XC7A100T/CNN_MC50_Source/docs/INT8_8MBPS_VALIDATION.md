> 소스 배포본: 실행 순서는 [README](../README.md)를 따른다. 검증 수치는 기존 개발본의 기록이며, 빌드·평가 결과 파일은 포함하지 않는다. 이 폴더의 export_mcdc.py는 모델 메모리와 CPU 정규화 표만 생성하고 시뮬레이션 fixture는 생성하지 않는다.

# PC 정규화·8Mbps 검증

Nexys A7-100T, xc7a100tcsg324-1, Vivado2024.1,100MHz.
Python이 float32 정규화·rint·clip 후 int8을 전송하고 FPGA는 입력 BRAM에
그대로 저장한다. 명령03은 단일추론,04는 물리 RO/LUT SNG MC50이다.
새 비트스트림은 output/nexys_a7_mc50_int8_8mbps/mnist_uart_mc50_int8_8mbps.bit.

## 기능 검사

- Python9개 검사 통과. 원본 픽셀256개 모두 normalize.mem과 동일한 비트패턴,
  이미 int8인 배열은 그대로 전송, 음수 byte checksum, signed score,
  기존 정수 CNN golden, MC entropy/MI·AUROC 검사.
- Vivado CNN6개 golden fixture 통과: pooled feature196+98 write, FC1568 read,
  정수 점수 및 mask 일치. PC에서 변환한 입력을 testbench가 제공한다.
- Vivado UART8Mbps13개 응답: 정상/연속/checksum/잘못된 명령/framing/timeout,
  RX/Conv1/Conv2/FC 중 reset 복구 및 RX bit period±2%.
- UART 전용 검사: 모든0~255 byte값을 nominal/±2%의 간격으로 연속 송신해
  768개 RX 확인.256개 TX 확인. 모든8N1 프레임은1250ns(125클럭).
- LUT16입력 exhaustive 검사, MC50 pin-level UART50응답 및 mask 고정 확인.
  시뮬레이션500개 점수가 각 반환 mask를 적용한 CPU 기준과 일치.
- 실물 COM6,8Mbps: 이전 raw 명령01/02 E4 거절, MC checksum E1/timeout E3
  복구,03→04→03→04 전환,1020개 점수 일치.

## 물리 구현

| 항목 | 결과 |
|---|---:|
| WNS | +0.060ns |
| WHS | +0.051ns |
| LUT | 5653 |
| FF | 5522 |
| BRAM tile | 10 |
| DSP | 0 |
| critical warning / error | 0 / 0 |

DRC는 기존과 같이 의도된 RO 루프 LUTLP-2 13개, FC bias ROM 경로
REQP-1840 3개를 보고한다. 동기식 CNN 경로의100MHz setup/hold를 통과했다.
물리 RO의 독립성·엔트로피를 이 기능 시험만으로 인증하지 않는다.
JTAG210292BF6B72A에 프로그램 후 DONE=1 확인. flash에는 기록하지 않았다.

실제 UART는8Mbps/8N1이며, 바이트 사이 handshake·USB·CNN 처리 시간 때문에
전체 이미지 처리시간은 순수 wire 시간보다 길다. 

## 실물1000개 전체 검사

MNIST900+KMNIST50+Fashion50,seed42. 총50000회 추론/500000개 점수가
실제 반환 mask를 적용한 Python 정수 모델과 모두 일치했다. 통신 오류0,
점수 불일치 이미지0. CPU 비교 포함 전체 시간86.99초다.

| 항목 | 결과 |
|---|---:|
| MNIST 정답 | 886/900 (98.44%) |
| OOD AUROC, entropy | 0.97912 |
| OOD AUROC, MI | 0.98163 |
| Conv1 관측 drop | 0.1252975 |
| Conv2 관측 drop | 0.1872450 |

RO의 각 실행 마스크가 다르므로 이전 실행과 확률/최종 예측이 약간 달라질 수 있다.
정규화 위치의 동등성은256개 입력 전수 비교와 같은 mask에 대한 점수 비교로 확인했다.

CSV (개발본 자료, 이 폴더에는 미포함),
요약 JSON (개발본 자료, 이 폴더에는 미포함),
점수·마스크 NPZ (개발본 자료, 이 폴더에는 미포함).

비트스트림 SHA-256: `d5691a2b67bca80e9c985adad64f1bac0bdb2ff9f35ab8f5c2d721a7bdf32a27`.
