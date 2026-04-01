/*
[MODULE_INFO_START]
Name: InputControl
Role: FPGA 입력과 PC 입력을 통합해 제어 명령으로 출력하는 모듈
Summary:
  - 입력 우선순위와 스위치 이벤트를 정리해 단일 입력 스트림을 구성합니다.
  - 모드/명령 코드 형태의 압축 인터페이스를 ControlUnit에 제공합니다.
[MODULE_INFO_END]
*/
module InputControl(
    input  wire       iClk,
    input  wire       iRst,
    input  wire [4:0] iBtnPulseFpga,    // from DebounceWrapper
    input  wire [2:0] iSwLevelFpga,     // from INPUTFPGA/SwitchInput
    input  wire [4:0] iBtnPulsePc,      // from ascii_decoder

    input  wire       iSw1PulsePc,      // from ascii_decoder
    input  wire       iSw2PulsePc,      // from ascii_decoder
    input  wire       iSw3PulsePc,      // from ascii_decoder
    input  wire       iReqFndPc,        // from ascii_decoder
    input  wire       iReqStatePc,      // from ascii_decoder
    input  wire       iReqStopwatchPc,  // from ascii_decoder
    input  wire       iReqWatchPc,      // from ascii_decoder
    input  wire       iReqHcsr04Pc,     // from ascii_decoder
    input  wire       iReqDht11Pc,      // from ascii_decoder

    output wire [1:0] oMode,            // to Control Unit
    output wire       oModeLock,        // to Control Unit
    output wire       oCmdValid,        // to Control Unit
    output wire [4:0] oCmdCode          // to Control Unit
);

    wire [2:0] wSwPulsePc;
    wire [4:0] wBtnPulsePrio;
    wire [2:0] wSwPulsePrio;

    assign wSwPulsePc = {iSw3PulsePc, iSw2PulsePc, iSw1PulsePc};

    InputPriority uInputPriority (
        .iClk        (iClk),
        .iRst        (iRst),
        .iBtnPulseFpga(iBtnPulseFpga),
        .iBtnPulsePc  (iBtnPulsePc),
        .iSwLevelFpga (iSwLevelFpga),
        .iSwPulsePc   (wSwPulsePc),
        .oBtnPulse    (wBtnPulsePrio),
        .oSwPulse     (wSwPulsePrio)
    );

    InputDistributor uInputDistributor (
        .iClk          (iClk),
        .iRst          (iRst),
        .iBtnPulse     (wBtnPulsePrio),
        .iSwLevel      (iSwLevelFpga),
        .iSwPulse      (wSwPulsePrio),
        .iReqFnd       (iReqFndPc),
        .iReqState     (iReqStatePc),
        .iReqStopwatch (iReqStopwatchPc),
        .iReqWatch     (iReqWatchPc),
        .iReqHcsr04    (iReqHcsr04Pc),
        .iReqDht11     (iReqDht11Pc),
        .oMode         (oMode),
        .oModeLock     (oModeLock),
        .oCmdValid     (oCmdValid),
        .oCmdCode      (oCmdCode)
    );

endmodule
