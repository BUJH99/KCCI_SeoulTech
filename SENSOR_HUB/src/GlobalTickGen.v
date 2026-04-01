/*
[MODULE_INFO_START]
Name: GlobalTickGen
Role: 시스템 공용 주기 신호를 생성하는 전역 틱 발생기
Summary:
  - 시스템 클록에서 1kHz와 2Hz 틱을 생성합니다.
  - 표시 스캔, 점멸, 주기 제어에 공통 기준 신호를 제공합니다.
[MODULE_INFO_END]
*/
module GlobalTickGen #(
    parameter P_SYS_CLK_HZ = 100_000_000
) (
    input  wire iClk,
    input  wire iRst,

    // Outputs (1????????)
    output reg  oTick1kHz,
    output reg  oTick2Hz
);
    localparam LP_1KHZ_CYCLES = P_SYS_CLK_HZ / 1_000;
    localparam LP_2HZ_CYCLES  = P_SYS_CLK_HZ / 2;

    reg [23:0] cnt1kHz;
    reg [26:0] cnt2Hz;

    // 1kHz (1ms) 1-Cycle Pulse ??? ???
    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            cnt1kHz   <= 24'd0;
            oTick1kHz <= 1'b0;
        end else begin
            if (cnt1kHz >= (LP_1KHZ_CYCLES - 1)) begin
                cnt1kHz   <= 24'd0;
                oTick1kHz <= 1'b1; // ??1???(10ns) ?????High ???
            end else begin
                cnt1kHz   <= cnt1kHz + 1'b1;
                oTick1kHz <= 1'b0;
            end
        end
    end
    // 2Hz (0.5s) 1-Cycle Pulse ??? ???
    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            cnt2Hz   <= 27'd0;
            oTick2Hz <= 1'b0;
        end else begin
            if (cnt2Hz >= (LP_2HZ_CYCLES - 1)) begin
                cnt2Hz   <= 27'd0;
                oTick2Hz <= 1'b1; // ??1???(10ns) ?????High ???
            end else begin
                cnt2Hz   <= cnt2Hz + 1'b1;
                oTick2Hz <= 1'b0;
            end
        end
    end

endmodule

