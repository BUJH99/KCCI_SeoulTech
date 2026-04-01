/*
[MODULE_INFO_START]
Name: WatchFsm
Role: 시계의 실행 상태와 편집 상태를 제어하는 2상태 FSM
Summary:
  - 실행 모드와 편집 모드를 전환하고 편집 단위를 관리합니다.
  - 현재 상태에 맞는 점멸 마스크와 제어 출력을 생성합니다.
StateDescription:
  - RUN: 시간 카운트를 진행하며 편집 기능을 비활성화한 기본 동작 상태입니다.
  - EDIT: 시간 카운트를 멈추고 편집 단위 선택 및 점멸 출력을 수행합니다.
[MODULE_INFO_END]
*/
module WatchFsm (
    input  wire        iClk,
    input  wire        iRst,

    // Controls (From InputDistributor / ControlUnit)
    input  wire        iEditModeToggle, // LP_CMD_WATCH_EDITMODE_TOGGLE
    input  wire        iEditUnitToggle, // LP_CMD_WATCH_EDITDIGIT_NEXT
    
    // Outputs
    output reg         oRun,
    output reg         oEditEn,
    output reg         oEditUnit,
    output reg  [3:0]  oBlinkMask
);

    localparam RUN  = 1'b0;
    localparam EDIT = 1'b1;

    reg state, state_d;
    reg editUnit, editUnit_d; // 0: Left, 1: Right

    // 1) ??? ?????? (Sequential)
    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            state    <= RUN;
            editUnit <= 1'b0;
        end else begin
            state    <= state_d;
            editUnit <= editUnit_d;
        end
    end

    // 2) ??? ??? ????? ??? (Combinational)
    always @(*) begin
        state_d    = state;
        editUnit_d = editUnit;

        case (state)
            RUN: begin
                if (iEditModeToggle) begin
                    state_d    = EDIT;
                    editUnit_d = 1'b0; // ??? ??? ????? ??????????
                end
            end
            EDIT: begin
                if (iEditModeToggle) begin
                    state_d = RUN;
                end else if (iEditUnitToggle) begin
                    editUnit_d = ~editUnit;
                end
            end
            default: begin
                state_d = RUN;
            end
        endcase
    end

    // 3) ??? ??? (Moore: state ??? ????????? ???)
    always @(*) begin
        oRun       = 1'b0;
        oEditEn    = 1'b0;
        oEditUnit  = 1'b0;
        oBlinkMask = 4'b0000;

        case (state)
            RUN: begin
                oRun       = 1'b1;
                oEditEn    = 1'b0;
                oEditUnit  = 1'b0;
                oBlinkMask = 4'b0000;
            end
            EDIT: begin
                oRun      = 1'b0;
                oEditEn   = 1'b1;
                oEditUnit = editUnit;
                if (editUnit == 1'b0) begin
                    oBlinkMask = 4'b1100;
                end else begin
                    oBlinkMask = 4'b0011;
                end
            end
            default: begin
                oRun       = 1'b0;
                oEditEn    = 1'b0;
                oEditUnit  = 1'b0;
                oBlinkMask = 4'b0000;
            end
        endcase
    end
endmodule

