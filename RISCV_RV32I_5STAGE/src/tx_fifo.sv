/*
[MODULE_INFO_START]
Name: tx_fifo
Role: UART †¡‹  ë°”ì´Š¸ë¥ ë²„í¼ë§í•˜Š” FIFO ëª¨ë“ˆ
Summary:
  - †¡‹  ê¸ °´„°ë¥  ˜•ƒœë¡ ž¥•˜ê³ ½ê¸ ¸„°Ž˜´Š¤ë¥  œê³µí•©‹ˆ‹¤.
  - ë¹„ì–´ žˆŒ/ê°“ ì° ƒƒœë¥ ì¶œë ¥•´ ƒœ„  „†¡  œ–´ —°™•©‹ˆ‹¤.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module tx_fifo #(
    parameter int unsigned P_DEPTH = 16
)(
    input  logic       iClk,
    input  logic       iRst,
    input  logic       iWrEn,
    input  logic [7:0] iWrData,
    input  logic       iRdEn,
    output logic [7:0] oRdData,
    output logic       oEmpty,
    output logic       oFull
);

    localparam int unsigned LP_AW = (P_DEPTH > 1) ? $clog2(P_DEPTH) : 1;
    localparam logic [LP_AW:0] LP_DEPTH_COUNT = (LP_AW + 1)'(P_DEPTH);
    localparam logic [LP_AW-1:0] LP_LAST_PTR = LP_AW'(P_DEPTH - 1);

    logic [7:0] MemFifo [0:P_DEPTH-1];
    logic [LP_AW-1:0] PtrWr;
    logic [LP_AW-1:0] PtrRd;
    logic [LP_AW:0]   Cnt;
    logic             WrEnInt;
    logic             RdEnInt;
    logic             PtrWrLast;
    logic             PtrRdLast;

    assign oEmpty  = (Cnt == '0);
    assign oFull   = (Cnt == LP_DEPTH_COUNT);
    assign oRdData = MemFifo[PtrRd];

    assign WrEnInt   = iWrEn && !oFull;
    assign RdEnInt   = iRdEn && !oEmpty;
    assign PtrWrLast = (PtrWr == LP_LAST_PTR);
    assign PtrRdLast = (PtrRd == LP_LAST_PTR);

    always_ff @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            PtrWr <= '0;
            PtrRd <= '0;
            Cnt <= '0;
        end else begin
            if (WrEnInt) begin
                MemFifo[PtrWr] <= iWrData;
                if (PtrWrLast) begin
                    PtrWr <= '0;
                end else begin
                    PtrWr <= PtrWr + 1'b1;
                end
            end

            if (RdEnInt) begin
                if (PtrRdLast) begin
                    PtrRd <= '0;
                end else begin
                    PtrRd <= PtrRd + 1'b1;
                end
            end

            unique case ({WrEnInt, RdEnInt})
                2'b10:   Cnt <= Cnt + 1'b1;
                2'b01:   Cnt <= Cnt - 1'b1;
                default: Cnt <= Cnt;
            endcase
        end
    end
endmodule
