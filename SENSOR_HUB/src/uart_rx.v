/*
[MODULE_INFO_START]
Name: uart_rx
Role: 오버샘플링 기반 UART 수신 FSM 모듈
Summary:
  - 시작 비트 검출 후 8비트 데이터와 정지 비트를 순차적으로 샘플링합니다.
  - 정상 수신 완료 시 유효 펄스와 수신 바이트를 출력합니다.
StateDescription:
  - IDLE: RX 라인의 시작 비트(LOW) 진입을 대기합니다.
  - START: 비트 중앙 시점에서 시작 비트를 재확인합니다.
  - DATA: 8비트 데이터를 LSB부터 순차 샘플링해 시프트 레지스터에 저장합니다.
  - STOP: 정지 비트(HIGH)를 확인하고 수신 정상 여부를 판정합니다.
  - DONE: 수신 완료 펄스를 출력하고 IDLE로 복귀합니다.
[MODULE_INFO_END]
*/
module uart_rx(
    input  wire       iClk,
    input  wire       iRst,
    input  wire       iSampleTick,
    input  wire       iUartRx,
    output wire       oRxValid,
    output wire [7:0] oRxData
);

    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] START = 3'd1;
    localparam [2:0] DATA  = 3'd2;
    localparam [2:0] STOP  = 3'd3;
    localparam [2:0] DONE  = 3'd4;

    reg [2:0] state;
    reg [2:0] state_d;

    reg [3:0] sampleCnt;
    reg [3:0] sampleCnt_d;
    reg [2:0] bitCnt;
    reg [2:0] bitCnt_d;
    reg [7:0] shift;
    reg [7:0] shift_d;
    reg [7:0] rxData;
    reg [7:0] rxData_d;

    wire wRxSync;

    sync_2ff uRxSync2ff (
        .iAsync(iUartRx),
        .iClk  (iClk),
        .iRst  (iRst),
        .oSync (wRxSync)
    );

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            state     <= IDLE;
            sampleCnt <= 4'd0;
            bitCnt    <= 3'd0;
            shift     <= 8'd0;
            rxData    <= 8'd0;
        end else begin
            state     <= state_d;
            sampleCnt <= sampleCnt_d;
            bitCnt    <= bitCnt_d;
            shift     <= shift_d;
            rxData    <= rxData_d;
        end
    end

    always @(*) begin
        state_d     = state;
        sampleCnt_d = sampleCnt;
        bitCnt_d    = bitCnt;
        shift_d     = shift;
        rxData_d    = rxData;

        case (state)
            IDLE: begin
                sampleCnt_d = 4'd0;
                bitCnt_d    = 3'd0;
                if (~wRxSync) begin
                    state_d = START;
                end
            end

            START: begin
                if (iSampleTick) begin
                    if (sampleCnt == 4'd7) begin
                        sampleCnt_d = 4'd0;
                        if (~wRxSync) begin
                            bitCnt_d = 3'd0;
                            state_d  = DATA;
                        end else begin
                            state_d = IDLE;
                        end
                    end else begin
                        sampleCnt_d = sampleCnt + 1'b1;
                    end
                end
            end

            DATA: begin
                if (iSampleTick) begin
                    if (sampleCnt == 4'd15) begin
                        sampleCnt_d      = 4'd0;
                        shift_d[bitCnt]  = wRxSync;
                        if (bitCnt == 3'd7) begin
                            state_d = STOP;
                        end else begin
                            bitCnt_d = bitCnt + 1'b1;
                        end
                    end else begin
                        sampleCnt_d = sampleCnt + 1'b1;
                    end
                end
            end

            STOP: begin
                if (iSampleTick) begin
                    if (sampleCnt == 4'd15) begin
                        sampleCnt_d = 4'd0;
                        if (wRxSync) begin
                            rxData_d = shift;
                            state_d  = DONE;
                        end else begin
                            state_d = IDLE;
                        end
                    end else begin
                        sampleCnt_d = sampleCnt + 1'b1;
                    end
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
    
    assign oRxValid = (state == DONE);
    assign oRxData  = rxData;

endmodule
