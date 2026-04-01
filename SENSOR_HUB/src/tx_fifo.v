/*
[MODULE_INFO_START]
Name: tx_fifo
Role: UART 송신 바이트를 버퍼링하는 FIFO 모듈
Summary:
  - 송신 대기 데이터를 큐 형태로 저장하고 읽기 인터페이스를 제공합니다.
  - 비어 있음/가득 참 상태를 출력해 상위 전송 제어와 연동합니다.
[MODULE_INFO_END]
*/
module tx_fifo #(
    parameter integer P_DEPTH = 16
)(
    input  wire       iClk,
    input  wire       iRst,
    input  wire       iWrEn,
    input  wire [7:0] iWrData,
    input  wire       iRdEn,
    output wire [7:0] oRdData,
    output wire       oEmpty,
    output wire       oFull
);

    localparam integer LP_AW = $clog2(P_DEPTH);

    reg [7:0] memFifo [0:P_DEPTH-1];
    reg [LP_AW-1:0] rPtrWr;
    reg [LP_AW-1:0] rPtrRd;
    reg [LP_AW:0]   rCount;

    wire wWrFire;
    wire wRdFire;
    wire wPtrWrLast;
    wire wPtrRdLast;

    assign oEmpty = (rCount == 0);
    assign oFull  = (rCount == P_DEPTH);
    assign oRdData = memFifo[rPtrRd];

    assign wWrFire = iWrEn & ~oFull;
    assign wRdFire = iRdEn & ~oEmpty;
    assign wPtrWrLast = (rPtrWr == (P_DEPTH - 1));
    assign wPtrRdLast = (rPtrRd == (P_DEPTH - 1));

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            rPtrWr <= {LP_AW{1'b0}};
            rPtrRd <= {LP_AW{1'b0}};
            rCount <= {(LP_AW+1){1'b0}};
        end else begin
            if (wWrFire) begin
                memFifo[rPtrWr] <= iWrData;
                if (wPtrWrLast) begin
                    rPtrWr <= {LP_AW{1'b0}};
                end else begin
                    rPtrWr <= rPtrWr + 1'b1;
                end
            end

            if (wRdFire) begin
                if (wPtrRdLast) begin
                    rPtrRd <= {LP_AW{1'b0}};
                end else begin
                    rPtrRd <= rPtrRd + 1'b1;
                end
            end

            case ({wWrFire, wRdFire})
                2'b10: rCount <= rCount + 1'b1;
                2'b01: rCount <= rCount - 1'b1;
                default: rCount <= rCount;
            endcase
        end
    end

endmodule
