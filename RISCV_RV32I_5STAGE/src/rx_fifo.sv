/*
[MODULE_INFO_START]
Name: rx_fifo
Role: UART 수신 바이트를 버퍼링하는 FIFO 모듈
Summary:
  - 수신 데이터 스트림의 쓰기/읽기 인터페이스를 제공합니다.
  - 비어 있음/가득 참 상태를 출력해 상위 제어와 연동합니다.
[MODULE_INFO_END]
*/
`timescale 1ns / 1ps

module rx_fifo #(
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

    logic [7:0] memFifo [0:P_DEPTH-1];
    logic [LP_AW-1:0] ptrWr;
    logic [LP_AW-1:0] ptrRd;
    logic [LP_AW:0]   count;
    logic             WrEnInt;
    logic             RdEnInt;
    logic             PtrWrLast;
    logic             PtrRdLast;

    assign oEmpty  = (count == '0);
    assign oFull   = (count == LP_DEPTH_COUNT);
    assign oRdData = memFifo[ptrRd];

    assign WrEnInt   = iWrEn && !oFull;
    assign RdEnInt   = iRdEn && !oEmpty;
    assign PtrWrLast = (ptrWr == LP_LAST_PTR);
    assign PtrRdLast = (ptrRd == LP_LAST_PTR);

    always_ff @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            ptrWr <= '0;
            ptrRd <= '0;
            count <= '0;
        end else begin
            if (WrEnInt) begin
                memFifo[ptrWr] <= iWrData;
                if (PtrWrLast) begin
                    ptrWr <= '0;
                end else begin
                    ptrWr <= ptrWr + 1'b1;
                end
            end

            if (RdEnInt) begin
                if (PtrRdLast) begin
                    ptrRd <= '0;
                end else begin
                    ptrRd <= ptrRd + 1'b1;
                end
            end

            unique case ({WrEnInt, RdEnInt})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
