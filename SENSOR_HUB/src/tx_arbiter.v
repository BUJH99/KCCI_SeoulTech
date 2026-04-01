/*
[MODULE_INFO_START]
Name: tx_arbiter
Role: 송신 데이터 소스를 선택하고 FIFO pop을 제어하는 중재기
Summary:
  - 송신 가능 시 sender 경로를 우선 선택하고 없으면 echo 경로를 선택합니다.
  - 선택된 소스에 맞춰 TX 시작 신호와 pop 제어를 생성합니다.
[MODULE_INFO_END]
*/
module tx_arbiter(
    input  wire       iTxBusy,
    input  wire       iSenderValid,
    input  wire [7:0] iSenderData,
    input  wire       iEchoValid,
    input  wire [7:0] iEchoData,
    output reg        oTxStart,
    output reg  [7:0] oTxData,
    output reg        oSenderPop,
    output reg        oEchoPop
);

    always @(*) begin
        oTxStart   = 1'b0;
        oTxData    = 8'h00;
        oSenderPop = 1'b0;
        oEchoPop   = 1'b0;

        if (~iTxBusy) begin
            if (iSenderValid) begin
                oTxStart   = 1'b1;
                oTxData    = iSenderData;
                oSenderPop = 1'b1;
            end else if (iEchoValid) begin
                oTxStart = 1'b1;
                oTxData  = iEchoData;
                oEchoPop = 1'b1;
            end
        end
    end

endmodule
