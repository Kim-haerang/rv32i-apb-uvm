# RV32I Multi-Cycle CPU · APB · GPIO · UVM

RV32I CPU 코드 작성·완성을 담당한 팀 프로젝트입니다. 2026년 9월 15일 코드 스냅샷을 정리했습니다.

대한상공회의소 AI 시스템 반도체 설계 과정에서 RV32I CPU를 다중 사이클 구조로 구성하고, APB를 통해 RAM과 GPIO 계열 주변 장치에 접근하도록 연결했습니다. CPU·APB 연결, 메모리 맵 주변 장치, UVM 기반 테스트벤치가 포함됩니다.

## 담당 역할

- **개인 담당:** RV32I CPU 코드 작성·완성, CPU 구조 및 명령어 동작 설명(발표 자료 1~14쪽)
- **팀 공동 결과:** CPU–APB–RAM–GPIO 통합 시스템과 UVM 검증 환경
- **개발 환경:** SystemVerilog, Vivado, UVM / Basys 3 핀 제약(100 MHz)

## 핵심 구현

- 명령어별 제어 신호와 다중 사이클 상태 전이 구성
- 단계 간 레지스터를 사용한 데이터 경로 및 PC 제어
- R/I 연산, 분기, 상위 즉시값, 점프, load/store 명령 처리
- 메모리 접근 시 APB 응답을 기다린 뒤 다음 CPU 상태로 전환

임베디드 SW와 연결되는 부분은 CPU의 load/store가 APB 전송과 MMIO 레지스터 접근으로 이어지는 과정입니다.

## 시스템 구조

```text
Instruction ROM ──> RV32I CPU ──> APB requester / address decoder
                      │                         ├── APB RAM
                      │                         ├── GPI  (switch 입력)
                      │                         ├── GPO  (LED 출력)
                      │                         └── GPIO (핀별 입출력)
                      └── CPU control unit + datapath

CPU/APB 신호 ──> UVM passive monitors ──> scoreboard / coverage
```

CPU 제어부는 `FETCH → DECODE → EXECUTE`를 거쳐, load/store 명령에서는 `MEM`, load 명령에서는 `WB` 상태를 추가로 사용합니다. APB requester는 `IDLE → SETUP → ACCESS` 상태로 요청을 전송하고, 주소 디코더가 주변 장치를 선택합니다.

## 코드 구성

| 경로 | 내용 |
| --- | --- |
| `rtl/control_unit.sv`, `rtl/datapath.sv` | 명령어별 제어 신호와 데이터 경로 |
| `rtl/rv32i_cpu.sv` | ROM, CPU, APB requester, RAM, GPI/GPO/GPIO 연결 |
| `rtl/apb_requester.sv` | APB 전송 상태 머신, 주소 디코더, 응답 MUX |
| `rtl/apb_ram.sv`, `rtl/apb_gpio.sv` | 메모리 및 주변 장치 레지스터 |
| `rtl/rom_code_apb_ram.mem` | 제공된 시뮬레이션용 명령어 이미지 |
| `sim/tb_rv32i_gpio_uvm.sv` | CPU/APB 모니터, scoreboard, coverage, 프로토콜 assertion |
| `constraints/Basys-3-Master.xdc` | ZIP에 포함된 Basys 3 핀 제약 파일 |

`rtl/data_memoery.sv`는 원본에 포함되어 있지만 현재 top에서는 인스턴스가 주석 처리되어 있습니다. 파일명도 원본 그대로 보존했습니다.

## 확인된 검증 범위

- 발표 자료에는 누적 합 55, APB RAM 읽기·쓰기, 분기, GPIO 동작의 시뮬레이션 분석이 제시됩니다.
- 포함된 **9월 15일 코드 스냅샷**의 UVM 테스트는 예상 트랜잭션 수를 `8`로 설정합니다. 발표 자료와 테스트 버전이 다를 수 있어, 발표의 통계 수치를 이 코드의 실행 결과로 인용하지 않습니다.
- 이 작업 환경에서 UVM 시뮬레이션을 다시 실행하지 않았습니다. `instruction_rom.sv`는 실행 시 `rom_code_apb_ram.mem`을 상대 경로로 읽습니다.

## 프로젝트 열기

Vivado에서 SystemVerilog 프로젝트를 만들고 `rtl/` 파일을 추가합니다. `rtl/pkg/rv32i_pkg.sv`를 다른 RTL보다 먼저 컴파일하도록 설정하고, include 경로에 `rtl/`을 추가합니다. RTL top은 `rv32i_top`입니다.

UVM을 지원하는 시뮬레이터에서 `sim/tb_rv32i_gpio_uvm.sv`를 시뮬레이션 소스로 추가하고 top을 `tb_rv32i_gpio_uvm`으로 지정합니다. UVM 라이브러리를 활성화하고, 시뮬레이터 실행 디렉터리에 `rtl/rom_code_apb_ram.mem`을 복사해야 합니다. 정확한 도구 버전과 실행 결과는 원본에 포함되어 있지 않습니다.

## 설계에서 다룬 문제

Single-Cycle CPU에서는 load 등의 긴 조합 경로가 타이밍 제약에 영향을 줍니다. 이 프로젝트에서는 단계 사이에 레지스터를 두는 Multi-Cycle 구조를 사용합니다. 명령어당 사이클 수가 증가하므로 실제 처리 성능은 동작 주파수와 전체 실행 사이클 수를 함께 비교해야 합니다.

현재 코드의 FND/UART용 주소 선택 신호는 확장용이며, 해당 주변 장치 인스턴스는 포함되어 있지 않습니다. 지원하는 모든 RV32I 명령의 완전한 적합성 검증 결과도 포함하지 않습니다.

## 자료

- [팀 발표 자료](https://docs.google.com/presentation/d/1dx39V54g26YiFuTDaLtVHyt-bsDZtylDVGxeWebt1m4/edit)
- [제공된 코드 ZIP](https://drive.google.com/file/d/1HOn2-sD6uFcWTwFUy5pnhqBNOyklPd-z/view)

