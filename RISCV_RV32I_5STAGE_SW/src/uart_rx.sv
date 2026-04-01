/*
[MODULE_INFO_START]
Name: uart_rx
Role: 오버샘플링 기반 UART 수신 FSM 모듈
Summary:
  - 시작 비트 검출 후 8비트 데이터와 정지 비트를 순차적으로 샘플링합니다.
  - 정상 수신 완료 시 유효 펄스와 수신 바이트를 출력합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module uart_rx(
    input  logic       iClk,
    input  logic       iRst,
    input  logic       iSampleTick,
    input  logic       iUartRx,
    output logic       oRxValid,
    output logic [7:0] oRxData
);

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP,
        DONE
    } state_e;

    state_e      state;
    state_e      state_d;
    logic [3:0]  SampleCnt;
    logic [3:0]  SampleCnt_d;
    logic [2:0]  BitCnt;
    logic [2:0]  BitCnt_d;
    logic [7:0]  Shift;
    logic [7:0]  Shift_d;
    logic [7:0]  RxData;
    logic [7:0]  RxData_d;
    logic        RxSync;

    sync_2ff uRxSync2ff (
        .iAsync(iUartRx),
        .iClk  (iClk),
        .iRst  (iRst),
        .oSync (RxSync)
    );

    always_ff @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            state     <= IDLE;
            SampleCnt <= '0;
            BitCnt    <= '0;
            Shift     <= '0;
            RxData    <= '0;
        end else begin
            state     <= state_d;
            SampleCnt <= SampleCnt_d;
            BitCnt    <= BitCnt_d;
            Shift     <= Shift_d;
            RxData    <= RxData_d;
        end
    end

    always_comb begin
        state_d     = state;
        SampleCnt_d = SampleCnt;
        BitCnt_d    = BitCnt;
        Shift_d     = Shift;
        RxData_d    = RxData;

        unique case (state)
            IDLE: begin
                SampleCnt_d = '0;
                BitCnt_d    = '0;
                if (!RxSync) begin
                    state_d = START;
                end
            end

            START: begin
                if (iSampleTick) begin
                    if (SampleCnt == 4'd7) begin
                        SampleCnt_d = '0;
                        if (!RxSync) begin
                            BitCnt_d = '0;
                            state_d  = DATA;
                        end else begin
                            state_d = IDLE;
                        end
                    end else begin
                        SampleCnt_d = SampleCnt + 1'b1;
                    end
                end
            end

            DATA: begin
                if (iSampleTick) begin
                    if (SampleCnt == 4'd15) begin
                        SampleCnt_d    = '0;
                        Shift_d[BitCnt] = RxSync;
                        if (BitCnt == 3'd7) begin
                            state_d = STOP;
                        end else begin
                            BitCnt_d = BitCnt + 1'b1;
                        end
                    end else begin
                        SampleCnt_d = SampleCnt + 1'b1;
                    end
                end
            end

            STOP: begin
                if (iSampleTick) begin
                    if (SampleCnt == 4'd15) begin
                        SampleCnt_d = '0;
                        if (RxSync) begin
                            RxData_d = Shift;
                            state_d  = DONE;
                        end else begin
                            state_d = IDLE;
                        end
                    end else begin
                        SampleCnt_d = SampleCnt + 1'b1;
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
    assign oRxData  = RxData;
endmodule
