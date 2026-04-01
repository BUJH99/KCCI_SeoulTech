/*
[MODULE_INFO_START]
Name: WatchCore
Role: 시계 FSM과 카운터를 통합한 시계 코어 모듈
Summary:
  - 시계 명령을 해석해 실행/편집 상태 제어 신호를 생성합니다.
  - 표시용 데이터와 전송용 확장 데이터를 함께 제공합니다.
[MODULE_INFO_END]
*/
module WatchCore (
    input  wire        iClk,
    input  wire        iRst,

    input  wire        iTick1kHz,
    input  wire [1:0]  iMode,
    input  wire        iCmdValid,
    input  wire [4:0]  iCmdCode,

    output wire [15:0] oFndData,
    output wire [31:0] oFullData,
    output wire [3:0]  oBlinkMask,
    output wire [3:0]  oDotMask,
    output wire        oEditActive
);

    localparam [1:0] LP_MODE_WATCH                = 2'd0;
    localparam [4:0] LP_CMD_MODE_LOCAL_RESET      = 5'd3;
    localparam [4:0] LP_CMD_WATCH_FMT_TOGGLE      = 5'd4;
    localparam [4:0] LP_CMD_WATCH_EDITMODE_TOGGLE = 5'd5;
    localparam [4:0] LP_CMD_WATCH_EDITDIGIT_NEXT  = 5'd6;
    localparam [4:0] LP_CMD_EDIT_INC              = 5'd20;
    localparam [4:0] LP_CMD_EDIT_DEC              = 5'd21;

    wire wRun;
    wire wEditEn;
    wire wEditUnit;

    wire wFormatToggle   = iCmdValid && (iCmdCode == LP_CMD_WATCH_FMT_TOGGLE);
    wire wEditModeToggle = iCmdValid && (iCmdCode == LP_CMD_WATCH_EDITMODE_TOGGLE);
    wire wEditUnitToggle = iCmdValid && (iCmdCode == LP_CMD_WATCH_EDITDIGIT_NEXT);
    wire wResetTime      = iCmdValid && (iCmdCode == LP_CMD_MODE_LOCAL_RESET) && (iMode == LP_MODE_WATCH);
    wire wInc            = iCmdValid && (iCmdCode == LP_CMD_EDIT_INC) && (iMode == LP_MODE_WATCH);
    wire wDec            = iCmdValid && (iCmdCode == LP_CMD_EDIT_DEC) && (iMode == LP_MODE_WATCH);

    reg formatFlag;
    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            formatFlag <= 1'b0;
        end else if (wFormatToggle) begin
            formatFlag <= ~formatFlag;
        end
    end

    assign oDotMask    = 4'b0100;
    assign oEditActive = wEditEn;

    WatchFsm uWatchFsm (
        .iClk            (iClk),
        .iRst           (iRst),
        .iEditModeToggle (wEditModeToggle),
        .iEditUnitToggle (wEditUnitToggle),
        .oRun            (wRun),
        .oEditEn         (wEditEn),
        .oEditUnit       (wEditUnit),
        .oBlinkMask      (oBlinkMask)
    );

    WatchCounter uWatchCounter (
        .iClk       (iClk),
        .iRst      (iRst),
        .iTick1kHz  (iTick1kHz),
        .iRun       (wRun),
        .iFormat    (formatFlag),
        .iEditEn    (wEditEn),
        .iEditUnit  (wEditUnit),
        .iInc       (wInc),
        .iDec       (wDec),
        .iResetTime (wResetTime),
        .oFndData   (oFndData),
        .oFullData  (oFullData)
    );

endmodule

