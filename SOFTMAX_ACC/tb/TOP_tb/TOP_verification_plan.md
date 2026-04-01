# SOFTMAX_ACC TOP Verification Plan

## 1. 목표
- `TOP`을 블랙박스 + 계층 프로브 관점으로 검증한다.
- frame 기반 softmax 파이프라인의 `valid/ready/last` 규약, backpressure, max-subtraction, 정규화 스칼라 생성, 출력 확률 스트림 동작을 검증한다.
- 입력 `iSAxisKeep` 무시 규약과 출력 `oMAxisKeep = 4'hF` 고정 규약을 검증한다.
- `TESTNAME=all` 회귀에서 시나리오 1~10을 순차 실행하고 기능 커버리지 95% 이상, 핵심 cross 100%를 달성한다.

## 2. DUT 동작 요약 (소스 기반)
- DUT: `TOP`
- 입력: `iClk`, `iRstn`, `iSAxisValid`, `iSAxisData[31:0]`, `iSAxisLast`, `iSAxisKeep[3:0]`, `iMAxisReady`
- 출력: `oSAxisReady`, `oMAxisValid`, `oMAxisData[31:0]`, `oMAxisLast`, `oMAxisKeep[3:0]`
- 핵심 동작:
  1. `Downscale`이 FP32 입력 프레임을 Q7.8로 변환해 저장하고 frame maximum을 추적한 뒤, 각 샘플에서 `max`를 뺀 값을 재생한다.
  2. `ExpSum -> Sum -> Ln` 경로가 `ln(sum(exp(x-max)))`에 해당하는 정규화 스칼라를 생성한다.
  3. `Sub`가 downscaled frame을 다시 읽어 정규화 스칼라를 빼고, `ExpOut`이 출력 확률 경로용 지수 근사를 수행한다.
  4. `U16ToFp32`가 U0.16 결과를 IEEE-754 FP32로 변환해 최종 `oMAxisData`로 출력한다.
  5. `oMAxisKeep`는 항상 `4'hF`이며 입력 `iSAxisKeep`는 기능적으로 사용되지 않는다.
  6. `wDownscale2Fanout_Ready = wDownscale2ExpSum_Ready & wDownscale2Sub_Ready` 이므로 fanout 양쪽이 동시에 준비되어야 replay beat가 진행된다.
  7. 구조상 한 번에 한 frame만 처리하며, 현재 frame이 완전히 배출되기 전까지 다음 frame을 받지 않는다.
  8. 주요 stage는 `iRstn` active-low 비동기 리셋으로 초기화된다.
  9. 내부 RAM/Frame buffer 저장 데이터 자체는 reset으로 clear되지 않을 수 있으므로, reset correctness는 stale state/valid/busy 제거와 frame isolation으로 판단해야 한다.

## 3. 현재 TB 구조 진단 (현행 코드 기준)
- `tb_top.sv`:
  - DUT 인스턴스가 TODO 상태로 주석 처리되어 있다.
  - `TESTNAME` 기반 시나리오 분기와 frame-level 제어가 없다.
  - generic `TopTest01`만 단일 실행한다.
- `interface.sv`:
  - `tb_data_in/out`, `tb_valid`, `tb_ready`만 정의된 generic handshake 인터페이스다.
  - DUT 실제 포트인 input/output AXIS 채널, `last`, `keep`가 반영되어 있지 않다.
- `objs/transaction.svh`:
  - 단일 `data + valid` transaction만 정의되어 있다.
  - frame 길이, `last` 위치, `keep`, input/output stall, 기대 결과 메타데이터가 없다.
- `env/scoreboard.svh`:
  - `compare()`가 `tx_actual.m_valid`만 반환하는 placeholder 상태다.
  - softmax 참조모델과 output frame 비교가 없다.
- `env/coverage.svh`:
  - `valid x data_lsb` 수준의 generic coverage만 있다.
  - frame 경계, stall, special input, result class를 측정하지 않는다.
- `tests/*`:
  - `base_test.svh`, `test_01.svh`, `test_02.svh`만 존재한다.
  - 현재는 transaction 개수 조정 중심으로, DUT 고유 기능 검증과는 거리가 있다.
- 결론: 현 TB는 재사용 가능한 뼈대는 있으나, `TOP`의 softmax 동작을 신뢰성 있게 판정할 수 있는 상태는 아니다.

## 4. 가정 및 제약 사항
- RTL(`src/*.v`)은 수정하지 않고 TB 자산만 확장한다.
- 권장 scoreboard 방식은 SV 내부 DUT mirror가 아니라, 외부 Python golden model이 frame 단위 expected output을 계산하고 SV가 DUT 실제 출력과 비교하는 구조다.
- 1차 pass/fail 기준은 Python golden model이 구현한 RTL LUT/고정소수점/rounding 규칙 기반 bit-accurate expected 값이다.
- 이상적인 floating-point softmax 비교는 2차 sanity check로만 사용한다.
- argmax 관련 판정은 raw FP32가 아니라 `Fp32ToQ78` 이후 DUT가 실제로 처리하는 Q7.8 유효 frame 기준으로 수행한다.
- quantization으로 동률 최대값이 생길 수 있으므로, argmax 비교 단위는 단일 index보다 `argmax set`을 기본으로 한다.
- 내부 stream 신호(`TbTop.uDut.*`)에 대한 계층 관측은 허용한다.
- 코드 커버리지는 범위 외로 두고 기능 커버리지 우선으로 완료 기준을 설정한다.
- 기본 회귀 입력은 finite IEEE-754 값을 대상으로 하되, special exponent(`Inf/NaN`)는 별도 edge 시나리오로 검증한다.
- 기본 파라미터는 `P_C_MAX=1024`, `P_ADDR_W=10`으로 본다.
- Python model은 frame-level 수치 golden만 담당한다.
- 프로토콜 검증은 소유권과 상태 의존성 기준으로 분리한다: signal-local DUT 출력 성질은 pure assertion, accepted frame/history 의미가 필요한 판정은 monitor/checker의 shadow state로 관리한다.
- TB/driver가 구동하는 입력 채널 성질은 environment assumption 또는 TB self-check로 관리한다.

## 5. 검증 아키텍처 계획
- 생성기(`generator`):
  - frame-oriented sequence item을 생성한다.
  - dynamic array 기반 input sample list, frame length, `last` 정책, `keep` 패턴, source/sink stall pattern을 포함한다.
- 드라이버(`driver`):
  - input source와 output sink backpressure를 분리 제어한다.
  - frame 단위 입력 구동, `iMAxisReady` throttle, reset/task helper를 제공한다.
- 모니터(`monitor`):
  - input/output AXIS beat를 frame 단위로 수집한다.
  - accepted input/output frame 기준 shadow state를 유지한다.
  - 계층 경로로 downscale replay, scalar handoff, output pipeline handshake를 보조 관측한다.
- 외부 golden model(`python reference model`):
  - monitor가 수집한 input frame을 JSON/CSV 형태로 기록한다.
  - Python이 frame 단위 expected output frame과 보조 메타데이터(`quantized_argmax_set`, `frame sum`, `scalar`, optional `raw_argmax`)를 계산한다.
- 체커(`scoreboard`):
  - SV 내부에서 DUT 수치 경로를 mirror하지 않는다.
  - Python golden 결과 파일을 읽어 output beat 수, `data`, `last`, `keep`, frame 순서를 비교한다.
- shadow-state checker:
  - accepted-frame 기반으로 frame 경계, reset abort, stale output, post-reset isolation, `last` 개수 정합성을 판단한다.
- 정적 체커(`assertions/assumptions`):
  - signal-local DUT 출력 채널 프로토콜은 assertion으로, 입력 채널 프로토콜은 environment assumption 또는 TB self-check로 분리 검출한다.
  - sign-off 집계에서 DUT assertion failure, shadow-state checker failure, ENV violation을 분리 관리한다.
- 회귀 운영:
  - `TESTNAME=<case>`와 `TESTNAME=all`을 모두 지원한다.
  - directed 시나리오로 기본 closure를 만든 뒤 `test_10_random_cov`로 잔여 coverage를 닫는다.

## 6. 최종 시나리오
1. `test_01_reset_matrix`
   - reset matrix 시나리오로 idle 상태뿐 아니라 in-flight 상태에서의 async reset 복구까지 검증한다.
   - 세부 케이스는 `capture reset`, `replay/fanout reset`, `output-valid reset`, `idle reset`으로 분리한다.
   - 핵심 확인 항목은 reset 뒤 stale output 부재, busy/state 완전 해제, 첫 새 frame의 완전한 frame isolation이다.
2. `test_02_singleton_frame`
   - frame 길이 1에서 출력이 정확히 1 beat이며 `oMAxisLast=1`, 확률 값이 1.0에 해당하는 FP32로 나오는지 검증한다.
3. `test_03_uniform_frame`
   - 동일 값으로 구성된 uniform frame에서 출력들이 서로 동일하고 frame 합이 1에 가깝게 유지되는지 검증한다.
   - 주 타깃 길이는 `3/5/7` 같은 non-power-of-two이며, `2`는 sanity check 용도로만 유지한다.
   - 목적은 쉬운 대칭성 확인보다 정규화/rounding/LUT 누적 오차가 awkward한 frame length에서 어떻게 나타나는지 확인하는 것이다.
4. `test_04_mixed_vector_directed`
   - 양수/음수 혼합, 고유 최대값 위치 변화(first/middle/last), quantization tie 가능성을 포함한 directed vector로 end-to-end 정합성과 quantized-domain argmax set 일관성을 검증한다.
5. `test_05_backpressure_protocol`
   - input gap, downstream stall, fanout stall 상황에서 beat drop/duplication 없이 `valid/ready/last`가 보존되는지 검증한다.
6. `test_06_frame_boundary_cmax`
   - 길이 `2`, `P_C_MAX-1`, `P_C_MAX` frame에 대해 일반적인 `iLast` 종료와 `P_C_MAX` 자동 종료 경계를 검증한다.
7. `test_07_boundary_collision_rearm`
   - `iLast`와 `cnt==P_C_MAX`가 같은 accepted beat에서 동시에 충돌하는 종료 조건을 검증한다.
   - 종료 직후 연속 입력이 들어올 때 next frame first beat가 old frame에 섞이지 않고 clean하게 재수락되는지 검증한다.
   - 핵심 확인 항목은 single close event, off-by-one 부재, post-termination re-arm integrity다.
8. `test_08_keep_ignore`
   - 동일 input frame에 대해 `iSAxisKeep`만 여러 패턴으로 바꿔도 결과가 동일한지 검증한다.
   - `oMAxisKeep`가 항상 `4'hF`인지 확인한다.
9. `test_09_special_fp32_policy`
   - zero/large finite/`Inf`/`NaN` 계열 입력에서 `Fp32ToQ78` 및 downstream 파이프라인의 saturation/zero/propagation 정책이 golden model과 일치하는지 검증한다.
   - 이 시나리오에서는 `iSAxisKeep`를 정상값으로 고정해 수치 정책만 분리 검증한다.
10. `test_10_random_cov`
   - directed warm-up 후 weighted-random frame 길이, data class, stall pattern으로 coverage closure를 수행한다.

## 7. 랜덤 전략
- random은 `test_10_random_cov`에서만 활성화한다.
- frame 길이는 `{1, 2, 3, 5, 7, 16, 63, 64, P_C_MAX-1, P_C_MAX}` 경계를 우선 가중하고, 그 외 구간은 균등 random으로 채운다.
- 이 중 uniform class에서는 `3/5/7` 같은 non-power-of-two 길이를 우선 가중해 정규화 오차 관측력을 높인다.
- source stall과 sink stall은 독립 난수로 주어 handshake 교차 상황을 강제로 만든다.
- input data class는 `uniform`, `mixed-sign`, `dominant-peak`, `near-equal`, `special-exp`를 분리해 샘플링한다.
- 재현성 확보를 위해 고정 seed(`0x20260320`)를 기본으로 사용한다.
- 시뮬레이션 시간이 큰 max-length frame은 directed와 random에서 각각 최소 1회 이상만 강제한다.

## 8. 체커 계획 (Scoreboard/Assertions)
### 8.1 Scoreboard (동적 체커)
- 내부 상태:
  - input frame queue
  - expected output frame
  - expected metadata(`quantized_argmax_set`, `sum_prob`, `frame_len`, `scenario tag`, optional `raw_argmax`)
  - frame/beat 인덱스와 scenario tag
- 비교 순서:
  1. input handshake로 실제 입력 frame을 수집
  2. frame 종료 시 input frame dump를 Python golden model에 전달하거나 사전 생성된 expected 파일을 로드
  3. Python이 계산한 expected output frame과 metadata를 scoreboard가 적재
  4. output handshake마다 `oMAxisData/oMAxisLast/oMAxisKeep` 비교
  5. frame 종료 후 beat 수, 마지막 위치, 잔여 데이터 유무 확인
- reset 처리 규칙:
  1. reset이 assertion되면 scoreboard는 미완료 input/output frame을 즉시 abort 처리한다.
  2. reset 이전 frame에 속한 pending expected output은 모두 폐기한다.
  3. reset 해제 후 첫 accepted frame은 반드시 새 frame id로 시작하며 reset 이전 frame과 비교 큐가 섞이지 않아야 한다.
- 보조 확인:
  - output argmax index가 post-`Fp32ToQ78` input frame의 `quantized_argmax_set`에 포함되는지 확인
  - output probability 합이 quantization 허용오차 내에서 1에 근접하는지 확인
  - raw FP32 argmax와 quantized argmax set이 다를 경우 fail 대신 diagnostic warning으로 분리 기록한다.
  - reset 이후 새 input frame을 accept하기 전까지 reset 이전 frame에 해당하는 output beat가 절대 발생하지 않는지 확인한다.
  - reset 이후 첫 새 frame의 output beat가 reset 이전 frame metadata/expected queue와 섞이지 않는지 확인한다.
- mismatch 로그:
  - testname, frame index, beat index, input vector, expected, actual, stall context를 포함한다.
- 권장 구현 메모:
  - Python 호출은 beat 단위가 아니라 frame 단위로 제한한다.
  - SV scoreboard는 수치 연산보다 결과 적재/비교와 에러 리포트에 집중한다.
  - protocol/history 위반은 scoreboard가 아니라 pure assertion/shadow-state checker/ENV checker에서 우선 검출한다.
  - ENV violation은 DUT fail 카운트에 합산하지 않는다.

### 8.2 Pure DUT Assertions (정적 체커)
- `no_xz_dut_outputs`
  - DUT가 구동하는 `oSAxisReady/oMAxisValid/oMAxisData/oMAxisLast/oMAxisKeep`의 X/Z를 금지한다.
- `hold_output_while_wait_ready`
  - `oMAxisValid && !iMAxisReady` 동안 `oMAxisData/oMAxisLast/oMAxisKeep`가 유지되어야 한다.
- `output_keep_constant`
  - `oMAxisKeep`는 항상 `4'hF`여야 한다.
- `fanout_handshake_consistency`
  - downscale fanout handshake와 downstream ready 결합 규칙이 내부 연결 규약과 일치해야 한다.
- `reset_clears_local_valids`
  - 관측 기준은 `posedge iClk` 샘플링으로 고정한다.
  - `iRstn` assertion 이후 첫 샘플링 clock까지 DUT 출력 포트 `oMAxisValid`는 `0`이어야 한다.
  - 동일 기준으로 내부 probe의 pipeline local valid(`Downscale/ExpSum/Sum/Ln/Sub/ExpOut/U16ToFp32`의 valid 계열)는 첫 샘플링 clock까지 clear되어야 한다.
- `reset_clears_busy_state`
  - 관측 기준은 내부 probe 기준으로 고정한다.
  - `iRstn` assertion 이후 첫 샘플링 clock까지 `busy/frameStored/readPending` 및 동등한 frame-in-flight 제어 상태가 idle 값으로 복귀해야 한다.

### 8.3 Accepted-Frame Shadow-State Checker
- `one_last_per_accepted_output_frame`
  - accepted output frame마다 `oMAxisLast`는 정확히 1회만 발생해야 한다.
- `no_new_frame_accept_before_old_frame_done`
  - accepted input frame 관점에서 현재 frame이 종료되기 전 다음 frame의 첫 beat가 수락되지 않아야 한다.
- `no_stale_output_after_reset`
  - reset 이전 accepted frame에 속한 output beat가 reset 이후에는 더 이상 accepted되지 않아야 한다.
- `post_reset_frame_isolation`
  - reset 이후 첫 accepted frame의 output은 reset 이전 frame shadow state와 완전히 분리되어야 한다.
- `accepted_frame_abort_on_reset`
  - reset 시점에 진행 중이던 partial input/output frame은 폐기 처리되고, 이후 checker state에 잔존하면 안 된다.
- 구현 원칙:
  - shadow state는 raw signal 변화가 아니라 `valid && ready`로 accepted된 beat/frame만 기준으로 진전한다.
  - checker failure는 DUT assertion failure와 별도 카운터로 관리한다.

### 8.4 Environment Assumptions / TB Self-Checks
- `hold_input_while_wait_ready`
  - `iSAxisValid && !oSAxisReady` 동안 `iSAxisData/iSAxisLast/iSAxisKeep`는 upstream master 책임으로 유지되어야 한다.
  - DUT assertion이 아니라 driver contract 또는 interface-level ENV checker로 분류한다.
- `legal_input_last_generation`
  - TB는 frame 내 마지막 beat에서만 `iSAxisLast`를 구동해야 하며, zero-length frame을 만들지 않는다.
- `no_tb_protocol_glitch_after_reset_release`
  - reset 해제 직후 TB가 X/Z 또는 반주기 glitch를 입력에 주지 않도록 self-check 한다.
- 운영 원칙:
  - ENV violation은 별도 카운터/로그로 집계하고 DUT failure와 분리한다.
  - DUT는 handshake로 실제 수락한 입력만 기준으로 scoreboard/shadow-state checker 비교를 수행한다.

## 9. Coverage 계획
- Coverpoints:
  - `cp_reset_phase` (`idle`, `capture`, `replay`, `output_valid`)
  - `cp_frame_len`
  - `cp_term_kind` (`iLast_only`, `cmax_only`, `iLast_and_cmax`)
  - `cp_post_term_rearm` (`delayed_next`, `back_to_back_next`)
  - `cp_input_class`
  - `cp_max_pos` (post-`Fp32ToQ78` 기준 최대 위치)
  - `cp_in_stall`
  - `cp_out_stall`
  - `cp_keep_kind`
  - `cp_special_fp32`
  - `cp_result_kind`
  - `cp_output_last`
- Crosses:
  - `cx_reset_phase_result = cp_reset_phase x cp_result_kind`
  - `cx_len_term = cp_frame_len x cp_term_kind` (length/termination 불가능 조합은 ignore)
  - `cx_term_rearm = cp_term_kind x cp_post_term_rearm`
  - `cx_class_maxpos = cp_input_class x cp_max_pos`
  - `cx_stall_pair = cp_in_stall x cp_out_stall`
  - `cx_len_result = cp_frame_len x cp_result_kind`
- 목표:
  - 전체 기능 커버리지 95% 이상
  - `cx_len_term`, `cx_term_rearm`, `cx_stall_pair`, `cx_len_result`, `cx_reset_phase_result` 100%
  - `oMAxisLast` 누락/중복 bin 0건

## 10. Coverage 매핑 표 (시나리오 ↔ cp/cx)
| 시나리오 | 주요 cp | 주요 cx |
|---|---|---|
| `test_01_reset_matrix` | `cp_reset_phase`, `cp_in_stall`, `cp_out_stall`, `cp_output_last` | `cx_reset_phase_result` |
| `test_02_singleton_frame` | `cp_frame_len`, `cp_result_kind`, `cp_output_last` | `cx_len_result` |
| `test_03_uniform_frame` | `cp_input_class`, `cp_frame_len`, `cp_max_pos` | `cx_class_maxpos`, `cx_len_result` |
| `test_04_mixed_vector_directed` | `cp_input_class`, `cp_max_pos`, `cp_result_kind` | `cx_class_maxpos` |
| `test_05_backpressure_protocol` | `cp_in_stall`, `cp_out_stall`, `cp_output_last` | `cx_stall_pair` |
| `test_06_frame_boundary_cmax` | `cp_frame_len`, `cp_term_kind` | `cx_len_term` |
| `test_07_boundary_collision_rearm` | `cp_term_kind`, `cp_post_term_rearm`, `cp_output_last` | `cx_term_rearm` |
| `test_08_keep_ignore` | `cp_keep_kind`, `cp_result_kind` | `cx_len_result` |
| `test_09_special_fp32_policy` | `cp_special_fp32`, `cp_result_kind` | `cx_len_result` |
| `test_10_random_cov` | 전체 cp | 전체 cx closure |

## 11. 파일별 구현 반영 계획
- `tb_top.sv`
  - DUT 실인스턴스 연결, `TESTNAME` dispatch, clock/reset/watchdog, wave dump, hierarchical probe hook를 반영한다.
- `interface.sv`
  - input/output AXIS 채널(`valid/ready/data/last/keep`)과 pure DUT assertion, ENV checker, 공통 task를 역할 분리해 정의하도록 재작성한다.
- `tb_pkg.sv`
  - softmax top 전용 transaction/component/test include를 유지하되 scenario 파일 수를 확장한다.
- `include/tb_defs.svh`
  - scenario id, input class, stall mode, tolerance, logging macro를 정의한다.
- `objs/config.svh`
  - seed, timeout, max frame length, coverage gate, stall knob, testname을 담도록 확장한다.
- `objs/transaction.svh`
  - 단일 beat가 아닌 frame transaction 구조로 교체한다.
- `components/generator.svh`
  - directed/random frame 생성기로 전환한다.
- `components/driver.svh`
  - source driver + sink ready driver 역할을 통합해 input/output 채널을 모두 제어하고, in-flight reset injection helper를 제공한다.
- `components/monitor.svh`
  - input/output frame 캡처와 accepted-frame shadow state 유지, reset 시점의 pipeline phase 태깅을 수행한다.
- `env/scoreboard.svh`
  - Python golden model 결과를 로드해 DUT 출력과 비교하는 비교기로 교체한다.
- `env/shadow_checker.svh` 또는 동등 책임
  - accepted-frame 기반 frame 경계/reset/stale output/post-reset isolation checker를 구현한다.
- `env/coverage.svh`
  - frame/data/stall/result 중심 cp/cx 정의로 교체한다.
- `env/environment.svh`
  - generator/driver/monitor/scoreboard/shadow checker/coverage 종료 조건과 mailbox fanout을 정리한다.
- `tb/TOP_tb/tools/top_golden_model.py` 또는 동등 경로
  - input frame dump를 받아 expected output frame/metadata를 생성하는 외부 reference model을 추가한다.
- `tests/base_test.svh`
  - 공통 reset, run, drain, summary, coverage gate와 mid-flight reset helper를 반영한다.
- `tests/test_01_*.svh` ~ `tests/test_10_*.svh`
  - 10개 시나리오를 개별 클래스로 분리 구현한다.

## 12. 완료 기준 (Exit Criteria)
1. `TESTNAME=all`에서 시나리오 1~10 PASS.
2. scoreboard mismatch 0건.
3. pure DUT assertion failure 0건.
4. accepted-frame shadow-state checker failure 0건.
5. ENV protocol violation 0건.
6. reset matrix(`idle/capture/replay/output_valid`)에서 stale output 0건, busy clear failure 0건, post-reset frame mixing 0건.
7. 기능 커버리지 95% 이상, `cx_len_term/cx_term_rearm/cx_stall_pair/cx_len_result/cx_reset_phase_result` 100%.
8. directed 회귀에서 `P_C_MAX` 경계 frame 1회 이상, 종료 충돌 + post-termination re-arm case 1회 이상, random 회귀에서 독립 seed 1회 이상 PASS.

## 13. 리스크/추적 메모
- `fpga_auto.yml`의 `hdl.top`은 `"Top"`인데 RTL/TB 명칭은 `TOP`이므로 자동화 elaboration 이름 정합성 확인이 필요하다.
- Python golden model도 이상적 softmax가 아니라 RTL LUT/rounding/saturation 규칙을 반영해야 오탐을 피할 수 있다.
- quantization 이후 동률 최대값이 생길 수 있으므로, argmax 관련 판정은 단일 winner 강제보다 `argmax set` 기반으로 설계해야 한다.
- `Fp32ToQ78`는 special exponent 입력을 saturation으로 처리하므로 `Inf/NaN` 기대 동작을 sign-off 전에 명확히 고정해야 한다.
- `P_C_MAX=1024` max-length random frame은 시뮬레이션 시간을 키우므로 boundary 가중치와 directed 분리가 필요하다.
- Python-SV 연동은 파일 경로, 실행 시점, Windows/Vivado 작업 디렉터리 차이로 인해 깨질 수 있으므로 frame dump/output 경로 규약을 초기에 고정해야 한다.
- input protocol 위반을 DUT assertion으로 잘못 분류하면 TB 구동 오류가 DUT failure로 오인되므로, input assumption/output assertion 분리를 초기 구현부터 강제해야 한다.
- RAM/Frame buffer 데이터 배열은 reset으로 clear되지 않을 수 있으므로, mid-flight reset 이후 stale data가 control residue를 통해 재노출되지 않는지 반드시 검증해야 한다.
- frame/history 의미를 pure assertion에 과도하게 밀어 넣으면 backpressure/reset 상황에서 오탐이 늘어나므로, accepted-frame 기준 shadow state checker 분리를 유지해야 한다.
