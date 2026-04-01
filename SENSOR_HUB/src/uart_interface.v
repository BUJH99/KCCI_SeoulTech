/*
[MODULE_INFO_START]
Name: uart_interface
Role: UART RX/TX, FIFO, 중재기를 통합한 인터페이스 모듈
Summary:
  - 수신 바이트는 디코더 경로로 전달하고 송신 큐와 루프백 경로를 관리합니다.
  - 송신 준비 상태와 백프레셔 정보를 상위 모듈에 제공합니다.
[MODULE_INFO_END]
*/
module uart_interface #(
    parameter integer P_CLK_HZ      = 100_000_000,
    parameter integer P_BAUD        = 9600,
    parameter integer P_OVERSAMPLE  = 16,
    parameter integer P_FIFO_DEPTH  = 16
)(
    input  wire       iClk,
    input  wire       iRst,
    input  wire       iUartRx,
    output wire       oUartTx,

    input  wire [7:0] iSenderData,
    input  wire       iSenderValid,
    output wire       oSenderReady,

    output wire [7:0] oDecoderData,
    output wire       oDecoderValid
);

    wire       wSampleTick;

    wire       wRxValid;
    wire [7:0] wRxData;

    wire [7:0] wRxFifoData;
    wire       wRxFifoEmpty;
    wire       wRxFifoFull;

    wire [7:0] wTxFifoData;
    wire       wTxFifoEmpty;
    wire       wTxFifoFull;

    wire       wTxStart;
    wire [7:0] wTxData;
    wire       wTxBusy;

    wire       wSenderPop;
    wire       wEchoPop;

    assign oSenderReady  = ~wTxFifoFull;
    assign oDecoderData  = wRxData;
    assign oDecoderValid = wRxValid;

    baud_rate_generator #(
        .P_CLK_HZ     (P_CLK_HZ),
        .P_BAUD       (P_BAUD),
        .P_OVERSAMPLE (P_OVERSAMPLE)
    ) uBaudRateGenerator (
        .iClk        (iClk),
        .iRst        (iRst),
        .oSampleTick (wSampleTick)
    );

    uart_rx uUartRx (
        .iClk        (iClk),
        .iRst        (iRst),
        .iSampleTick (wSampleTick),
        .iUartRx     (iUartRx),
        .oRxValid    (wRxValid),
        .oRxData     (wRxData)
    );

    rx_fifo #(
        .P_DEPTH (P_FIFO_DEPTH)
    ) uRxFifo (
        .iClk    (iClk),
        .iRst    (iRst),
        .iWrEn   (wRxValid),
        .iWrData (wRxData),
        .iRdEn   (wEchoPop),
        .oRdData (wRxFifoData),
        .oEmpty  (wRxFifoEmpty),
        .oFull   (wRxFifoFull)
    );

    tx_fifo #(
        .P_DEPTH (P_FIFO_DEPTH)
    ) uTxFifo (
        .iClk    (iClk),
        .iRst    (iRst),
        .iWrEn   (iSenderValid),
        .iWrData (iSenderData),
        .iRdEn   (wSenderPop),
        .oRdData (wTxFifoData),
        .oEmpty  (wTxFifoEmpty),
        .oFull   (wTxFifoFull)
    );

    tx_arbiter uTxArbiter (
        .iTxBusy     (wTxBusy),
        .iSenderValid(~wTxFifoEmpty),
        .iSenderData (wTxFifoData),
        .iEchoValid  (~wRxFifoEmpty),
        .iEchoData   (wRxFifoData),
        .oTxStart    (wTxStart),
        .oTxData     (wTxData),
        .oSenderPop  (wSenderPop),
        .oEchoPop    (wEchoPop)
    );

    uart_tx uUartTx (
        .iClk        (iClk),
        .iRst        (iRst),
        .iSampleTick (wSampleTick),
        .iTxStart    (wTxStart),
        .iTxData     (wTxData),
        .oUartTx     (oUartTx),
        .oTxBusy     (wTxBusy),
        .oTxDone     ()
    );

endmodule
