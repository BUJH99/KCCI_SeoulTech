/*
[MODULE_INFO_START]
Name: uart_tx
Role: 오버샘플링 기준으로 동작하는 UART 송신 FSM 모듈
Summary:
  - 시작 비트, 8비트 데이터, 정지 비트를 규격 순서로 전송합니다.
  - 송신 중 busy와 완료 done 신호를 생성해 상위 제어와 연동합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module uart_tx(
    input  logic       iClk,
    input  logic       iRst,
    input  logic       iSampleTick,
    input  logic       iTxStart,
    input  logic [7:0] iTxData,
    output logic       oUartTx,
    output logic       oTxBusy,
    output logic       oTxDone
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

    always_ff @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            state     <= IDLE;
            SampleCnt <= '0;
            BitCnt    <= '0;
            Shift     <= '0;
        end else begin
            state     <= state_d;
            SampleCnt <= SampleCnt_d;
            BitCnt    <= BitCnt_d;
            Shift     <= Shift_d;
        end
    end

    always_comb begin
        state_d     = state;
        SampleCnt_d = SampleCnt;
        BitCnt_d    = BitCnt;
        Shift_d     = Shift;

        unique case (state)
            IDLE: begin
                SampleCnt_d = '0;
                BitCnt_d    = '0;
                if (iTxStart) begin
                    Shift_d = iTxData;
                    state_d = START;
                end
            end

            START: begin
                if (iSampleTick) begin
                    if (SampleCnt == 4'd15) begin
                        SampleCnt_d = '0;
                        BitCnt_d    = '0;
                        state_d     = DATA;
                    end else begin
                        SampleCnt_d = SampleCnt + 1'b1;
                    end
                end
            end

            DATA: begin
                if (iSampleTick) begin
                    if (SampleCnt == 4'd15) begin
                        SampleCnt_d = '0;
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
                        state_d     = DONE;
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

    always_comb begin
        oUartTx = 1'b1;
        oTxBusy = 1'b0;
        oTxDone = 1'b0;

        unique case (state)
            START: begin
                oUartTx = 1'b0;
                oTxBusy = 1'b1;
            end

            DATA: begin
                oUartTx = Shift[BitCnt];
                oTxBusy = 1'b1;
            end

            STOP: begin
                oUartTx = 1'b1;
                oTxBusy = 1'b1;
            end

            DONE: begin
                oUartTx = 1'b1;
                oTxBusy = 1'b1;
                oTxDone = 1'b1;
            end

            default: begin
                oUartTx = 1'b1;
                oTxBusy = 1'b0;
                oTxDone = 1'b0;
            end
        endcase
    end
endmodule
