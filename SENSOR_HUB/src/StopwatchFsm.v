/*
[MODULE_INFO_START]
Name: StopwatchFsm
Role: 스톱워치의 실행 상태와 편집 상태를 제어하는 FSM
Summary:
  - 실행 토글, 편집 토글, 편집 단위 전환 입력을 처리합니다.
  - 실행 제어, 편집 활성, 점멸 마스크 출력을 상태에 맞게 생성합니다.
StateDescription:
  - RUN: 스톱워치 실행/정지 토글을 처리하고 일반 표시 출력을 유지합니다.
  - EDIT: 실행을 멈추고 편집 단위를 전환하며 선택 자리 점멸을 출력합니다.
[MODULE_INFO_END]
*/
module StopwatchFsm (
    input  wire        iClk,
    input  wire        iRst,
    input  wire        iEditModeToggle,
    input  wire        iEditUnitToggle,
    input  wire        iRunToggle,
    input  wire        iPauseReq,

    output reg         oRun,
    output reg         oEditEn,
    output reg         oEditUnit,
    output reg  [3:0]  oBlinkMask
);

    localparam RUN  = 1'b0;
    localparam EDIT = 1'b1;

    reg state;
    reg state_d;
    reg editUnit;
    reg editUnit_d;
    reg runArmed;
    reg runArmed_d;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            state    <= RUN;
            editUnit <= 1'b0;
            runArmed <= 1'b0;
        end else begin
            state    <= state_d;
            editUnit <= editUnit_d;
            runArmed <= runArmed_d;
        end
    end

    always @(*) begin
        state_d    = state;
        editUnit_d = editUnit;
        runArmed_d = runArmed;

        if (iPauseReq) begin
            state_d    = RUN;
            editUnit_d = 1'b0;
            runArmed_d = 1'b0;
        end else begin
            case (state)
                RUN: begin
                    if (iEditModeToggle) begin
                        state_d    = EDIT;
                        editUnit_d = 1'b0;
                    end else if (iRunToggle) begin
                        runArmed_d = ~runArmed;
                    end
                end

                EDIT: begin
                    if (iEditModeToggle) begin
                        state_d    = RUN;
                    end else if (iEditUnitToggle) begin
                        editUnit_d = ~editUnit;
                    end
                end

                default: begin
                    state_d = RUN;
                end
            endcase
        end
    end

    always @(*) begin
        oRun       = 1'b0;
        oEditEn    = 1'b0;
        oEditUnit  = 1'b0;
        oBlinkMask = 4'b0000;

        case (state)
            RUN: begin
                oRun       = runArmed;
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

