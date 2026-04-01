/*
[MODULE_INFO_START]
Name: StopwatchCounter
Role: 스톱워치 시간 값을 BCD로 카운트하고 편집하는 모듈
Summary:
  - 1kHz 틱을 기반으로 내부 10ms 시간 기준을 생성합니다.
  - 실행/정지/편집 명령에 따라 BCD 자리 값을 갱신합니다.
[MODULE_INFO_END]
*/
module StopwatchCounter (
    input  wire        iClk,
    input  wire        iRst,

    // Controls
    input  wire        iTick1kHz,  // 1ms ??? ??
    input  wire        iRun,       // 1: ???????? ????????????? ???
    input  wire        iFormat,    // 0: HH:MM, 1: SS:ms
    input  wire        iEditEn,    // 1: Edit ?????
    input  wire        iEditUnit,  // 0: ??? ???, 1: ??? ???
    input  wire        iInc,       // ??? ????????
    input  wire        iDec,       // ??? ????????
    input  wire        iResetTime, // ????? ??? ???

    // Output Data
    output wire [15:0] oFndData,   // FND??4????? BCD ?????(16bit)
    output wire [31:0] oFullData   // UART??8????32bit ??? BCD ?????
);

    // 1) 1ms -> 10ms ??? prescaler
    reg [3:0] cnt1ms, cnt1ms_d;
    wire tick_10ms = (iRun == 1'b1) && iTick1kHz && (cnt1ms == 4'd9);

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            cnt1ms <= 4'd0;
        end else begin
            cnt1ms <= cnt1ms_d;
        end
    end

    always @(*) begin
        cnt1ms_d = cnt1ms;
        if (iResetTime) begin
            cnt1ms_d = 4'd0;
        end else if (iRun && iTick1kHz) begin
            if (cnt1ms == 4'd9) cnt1ms_d = 4'd0;
            else cnt1ms_d = cnt1ms + 1;
        end
    end

    // 2) ??? ??? ??? ?????
    wire edit_h  = iEditEn && (iFormat == 1'b0) && (iEditUnit == 1'b0);
    wire edit_m  = iEditEn && (iFormat == 1'b0) && (iEditUnit == 1'b1);
    wire edit_s  = iEditEn && (iFormat == 1'b1) && (iEditUnit == 1'b0);
    wire edit_cs = iEditEn && (iFormat == 1'b1) && (iEditUnit == 1'b1);

    // 3) BcdCounter ????????
    wire [3:0] cs_tens,   cs_ones;
    wire [3:0] sec_tens,  sec_ones;
    wire [3:0] min_tens,  min_ones;
    wire [3:0] hour_tens, hour_ones;

    wire carry_cs, carry_sec, carry_min, carry_hour; // hour carry????????

    BcdCounter #( .P_MAX_TENS(9), .P_MAX_ONES(9) ) uCsCounter (
        .iClk   (iClk),
        .iRst  (iRst),
        .iTick  (tick_10ms),
        .iInc   (iInc && edit_cs),
        .iDec   (iDec && edit_cs),
        .iReset (iResetTime),
        .oTens  (cs_tens),
        .oOnes  (cs_ones),
        .oCarry (carry_cs)
    );

    BcdCounter #( .P_MAX_TENS(5), .P_MAX_ONES(9) ) uSecCounter (
        .iClk   (iClk),
        .iRst  (iRst),
        .iTick  (carry_cs),
        .iInc   (iInc && edit_s),
        .iDec   (iDec && edit_s),
        .iReset (iResetTime),
        .oTens  (sec_tens),
        .oOnes  (sec_ones),
        .oCarry (carry_sec)
    );

    BcdCounter #( .P_MAX_TENS(5), .P_MAX_ONES(9) ) uMinCounter (
        .iClk   (iClk),
        .iRst  (iRst),
        .iTick  (carry_sec),
        .iInc   (iInc && edit_m),
        .iDec   (iDec && edit_m),
        .iReset (iResetTime),
        .oTens  (min_tens),
        .oOnes  (min_ones),
        .oCarry (carry_min)
    );

    // Stopwatch Hour: ??? 99 (Watch?? ??????????
    BcdCounter #( .P_MAX_TENS(9), .P_MAX_ONES(9) ) uHourCounter (
        .iClk   (iClk),
        .iRst  (iRst),
        .iTick  (carry_min),
        .iInc   (iInc && edit_h),
        .iDec   (iDec && edit_h),
        .iReset (iResetTime),
        .oTens  (hour_tens),
        .oOnes  (hour_ones),
        .oCarry (carry_hour)
    );

    // 4) ????? (oFndData ?????
    wire [3:0] left_tens  = (iFormat == 1'b0) ? hour_tens : sec_tens;
    wire [3:0] left_ones  = (iFormat == 1'b0) ? hour_ones : sec_ones;
    wire [3:0] right_tens = (iFormat == 1'b0) ? min_tens  : cs_tens;
    wire [3:0] right_ones = (iFormat == 1'b0) ? min_ones  : cs_ones;

    assign oFndData = {left_tens, left_ones, right_tens, right_ones};
    assign oFullData = {hour_tens, hour_ones, min_tens, min_ones, sec_tens, sec_ones, cs_tens, cs_ones};

endmodule

