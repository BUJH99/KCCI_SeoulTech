/*
[MODULE_INFO_START]
Name: Hcsr04Core
Role: HC-SR04 초음파 센서의 트리거 생성과 거리 측정을 수행하는 코어
Summary:
  - 시작 요청 시 10us 트리거를 출력하고 에코 응답을 대기합니다.
  - 에코 폭을 계측해 거리 값으로 변환하고 타임아웃을 처리합니다.
StateDescription:
  - IDLE: 측정 요청(iStart) 대기 및 내부 카운터 초기화 상태입니다.
  - TRIG_HIGH: HC-SR04에 트리거 펄스를 출력하는 상태입니다.
  - WAIT_ECHO_HIGH: 에코 신호가 시작되기를 타임아웃과 함께 대기합니다.
  - ECHO_MEASURE: 에코 HIGH 폭을 계측해 거리 카운트를 누적합니다.
  - DONE: 측정 결과를 확정하고 oValid를 1클록 출력한 뒤 IDLE로 복귀합니다.
[MODULE_INFO_END]
*/
module Hcsr04Core #(
    parameter P_SYS_CLK_HZ      = 100_000_000,
    parameter P_TRIG_US         = 10,
    parameter P_WAIT_TIMEOUT_US = 5_000,
    parameter P_ECHO_TIMEOUT_US = 38_000
)(
    input  wire        iClk,
    input  wire        iRst,
    input  wire        iStart,
    input  wire        iEcho,
    output reg         oTrig,
    output reg  [15:0] oDistance,
    output reg         oValid
);

    localparam integer LP_1_US                = P_SYS_CLK_HZ / 1_000_000;
    localparam integer LP_TRIG_CYCLES         = P_TRIG_US * LP_1_US;
    localparam integer LP_WAIT_TIMEOUT_CYCLES = P_WAIT_TIMEOUT_US * LP_1_US;
    localparam integer LP_ECHO_TIMEOUT_CYCLES = P_ECHO_TIMEOUT_US * LP_1_US;
    localparam integer LP_CYCLES_PER_CM       = 58 * LP_1_US;

    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] TRIG_HIGH      = 3'd1;
    localparam [2:0] WAIT_ECHO_HIGH = 3'd2;
    localparam [2:0] ECHO_MEASURE   = 3'd3;
    localparam [2:0] DONE           = 3'd4;

    reg [2:0]  state;
    reg [2:0]  state_d;
    reg [23:0] trigCnt;
    reg [23:0] trigCnt_d;
    reg [23:0] waitCnt;
    reg [23:0] waitCnt_d;
    reg [23:0] echoCnt;
    reg [23:0] echoCnt_d;
    reg [23:0] cmCycleCnt;
    reg [23:0] cmCycleCnt_d;
    reg [15:0] distCnt;
    reg [15:0] distCnt_d;
    reg        echoIdleLevel;
    reg        echoIdleLevel_d;

    wire wEchoSync;

    sync_2ff uEchoSync2ff (
        .iAsync (iEcho),
        .iClk   (iClk),
        .iRst   (iRst),
        .oSync  (wEchoSync)
    );

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            state       <= IDLE;
            trigCnt     <= 24'd0;
            waitCnt     <= 24'd0;
            echoCnt     <= 24'd0;
            cmCycleCnt  <= 24'd0;
            distCnt     <= 16'd0;
            echoIdleLevel <= 1'b0;
            oDistance   <= 16'd0;
        end else begin
            state       <= state_d;
            trigCnt     <= trigCnt_d;
            waitCnt     <= waitCnt_d;
            echoCnt     <= echoCnt_d;
            cmCycleCnt  <= cmCycleCnt_d;
            distCnt     <= distCnt_d;
            echoIdleLevel <= echoIdleLevel_d;

            if (state_d == DONE) begin
                oDistance <= distCnt_d;
            end
        end
    end

    always @(*) begin
        state_d      = state;
        trigCnt_d    = trigCnt;
        waitCnt_d    = waitCnt;
        echoCnt_d    = echoCnt;
        cmCycleCnt_d = cmCycleCnt;
        distCnt_d    = distCnt;
        echoIdleLevel_d = echoIdleLevel;

        case (state)
            IDLE: begin
                trigCnt_d    = 24'd0;
                waitCnt_d    = 24'd0;
                echoCnt_d    = 24'd0;
                cmCycleCnt_d = 24'd0;
                distCnt_d    = 16'd0;

                if (iStart) begin
                    state_d = TRIG_HIGH;
                end
            end

            TRIG_HIGH: begin
                if (trigCnt >= (LP_TRIG_CYCLES - 1)) begin
                    trigCnt_d = 24'd0;
                    waitCnt_d = 24'd0;
                    echoIdleLevel_d = wEchoSync;
                    state_d   = WAIT_ECHO_HIGH;
                end else begin
                    trigCnt_d = trigCnt + 24'd1;
                end
            end

            WAIT_ECHO_HIGH: begin
                if (wEchoSync != echoIdleLevel) begin
                    waitCnt_d    = 24'd0;
                    echoCnt_d    = 24'd0;
                    cmCycleCnt_d = 24'd0;
                    distCnt_d    = 16'd0;
                    state_d      = ECHO_MEASURE;
                end else if (waitCnt >= (LP_WAIT_TIMEOUT_CYCLES - 1)) begin
                    distCnt_d = 16'hFFFF;
                    state_d   = DONE;
                end else begin
                    waitCnt_d = waitCnt + 24'd1;
                end
            end

            ECHO_MEASURE: begin
                if (wEchoSync != echoIdleLevel) begin
                    if (echoCnt >= (LP_ECHO_TIMEOUT_CYCLES - 1)) begin
                        distCnt_d = 16'hFFFF;
                        state_d   = DONE;
                    end else begin
                        echoCnt_d = echoCnt + 24'd1;
                        if (cmCycleCnt >= (LP_CYCLES_PER_CM - 1)) begin
                            cmCycleCnt_d = 24'd0;
                            distCnt_d    = distCnt + 16'd1;
                        end else begin
                            cmCycleCnt_d = cmCycleCnt + 24'd1;
                        end
                    end
                end else begin
                    state_d = DONE;
                end
            end

            DONE: begin
                state_d = IDLE;
            end

            default: begin
                state_d = IDLE;
            end
        endcase
    end

    always @(*) begin
        oTrig  = 1'b0;
        oValid = 1'b0;

        case (state)
            TRIG_HIGH: begin
                oTrig = 1'b1;
            end
            DONE: begin
                oValid = 1'b1;
            end
            default: begin
                oTrig  = 1'b0;
                oValid = 1'b0;
            end
        endcase
    end

endmodule

