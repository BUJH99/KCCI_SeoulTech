/*
[MODULE_INFO_START]
Name: Dht11Core
Role: DHT11 1선 통신으로 40비트 데이터를 수집하는 코어
Summary:
  - 시작 신호, 응답 대기, 40비트 수신, 체크섬 검증 절차를 수행합니다.
  - 측정 완료 시 유효 신호와 온습도 데이터를 출력합니다.
StateDescription:
  - IDLE: 측정 시작 요청(iStart)을 대기하는 기본 상태입니다.
  - START_LOW: 센서 시작 조건을 위해 데이터 라인을 일정 시간 LOW로 구동합니다.
  - START_HIGH: 라인을 해제한 뒤 센서 응답의 첫 하강 에지를 대기합니다.
  - WAIT_LOW: 센서 응답 LOW 구간의 종료(상승 에지)를 대기합니다.
  - WAIT_HIGH: 센서 응답 HIGH 구간의 종료(하강 에지)를 대기합니다.
  - READ_40BIT: 각 비트의 HIGH 폭을 측정해 40비트 데이터를 시프트 저장합니다.
  - CHECKSUM: 수신 데이터의 체크섬 일치 여부를 검사합니다.
  - DONE: 검증 완료 후 oValid를 발생시키고 IDLE로 복귀합니다.
[MODULE_INFO_END]
*/
module Dht11Core #(
    parameter integer P_SYS_CLK_HZ            = 100_000_000,
    parameter integer P_START_LOW_US          = 18_000,
    parameter integer P_BIT_HIGH_THRESHOLD_US = 40,
    parameter integer P_LINE_TIMEOUT_US       = 200
)(
    input  wire        iClk,
    input  wire        iRst,
    input  wire        iStart,
    inout  wire        ioData,
    output reg  [15:0] oTemp,
    output reg  [15:0] oHumi,
    output reg         oValid
);

    // ----------------------------------------------------
    // 1) Parameters & State Encoding
    // ----------------------------------------------------
    localparam LP_1_US                   = P_SYS_CLK_HZ / 1_000_000;
    localparam LP_START_LOW_CYCLES       = P_START_LOW_US * LP_1_US;
    localparam LP_BIT_HIGH_THRESHOLD_CYC = P_BIT_HIGH_THRESHOLD_US * LP_1_US;
    localparam LP_TIMEOUT_CYCLES         = P_LINE_TIMEOUT_US * LP_1_US;

    localparam IDLE       = 3'd0;
    localparam START_LOW  = 3'd1;
    localparam START_HIGH = 3'd2;
    localparam WAIT_LOW   = 3'd3;
    localparam WAIT_HIGH  = 3'd4;
    localparam READ_40BIT = 3'd5;
    localparam CHECKSUM   = 3'd6;
    localparam DONE       = 3'd7;

    // ----------------------------------------------------
    // 2) Registers / Wires
    // ----------------------------------------------------
    reg [2:0]  state, state_d;
    reg [23:0] cntTimer, cntTimer_d;
    reg [5:0]  cntBit, cntBit_d;
    reg [39:0] dataShift, dataShift_d;

    reg        dataOut, dataOut_d;
    reg        dataDir, dataDir_d; // 1: Output, 0: Input (High-Z)

    reg        dataDelay;
    wire       wDataIn;
    wire       wEdgeFalling;
    wire       wEdgeRising;

    sync_2ff uDataSync2ff (
        .iAsync (ioData),
        .iClk   (iClk),
        .iRst   (iRst),
        .oSync  (wDataIn)
    );

    // ----------------------------------------------------
    // 3) Sequential Logic: state/register update
    // ----------------------------------------------------
    assign ioData = (dataDir == 1'b1) ? dataOut : 1'bz;
    
    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            dataDelay <= 1'b1;
        end else begin
            dataDelay <= wDataIn;
        end
    end

    assign wEdgeFalling = (dataDelay == 1'b1 && wDataIn == 1'b0);
    assign wEdgeRising  = (dataDelay == 1'b0 && wDataIn == 1'b1);

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            state     <= IDLE;
            cntTimer  <= 24'd0;
            cntBit    <= 6'd0;
            dataShift <= 40'd0;
            dataDir   <= 1'b0;
            dataOut   <= 1'b1;
        end else begin
            state     <= state_d;
            cntTimer  <= cntTimer_d;
            cntBit    <= cntBit_d;
            dataShift <= dataShift_d;
            dataDir   <= dataDir_d;
            dataOut   <= dataOut_d;
        end
    end

    // ----------------------------------------------------
    // 4. Combinational Logic (FSM & Datapath)
    // ----------------------------------------------------
    always @(*) begin
        state_d     = state;
        cntTimer_d  = cntTimer;
        cntBit_d    = cntBit;
        dataShift_d = dataShift;
        dataDir_d   = dataDir;
        dataOut_d   = dataOut;

        case (state)
            IDLE: begin
                dataDir_d  = 1'b0;
                dataOut_d  = 1'b1;
                cntTimer_d = 24'd0;
                cntBit_d   = 6'd0;
                
                if (iStart) begin
                    state_d    = START_LOW;
                    dataDir_d  = 1'b1; // Drive LOW
                    dataOut_d  = 1'b0;
                end
            end

            START_LOW: begin
                if (cntTimer >= LP_START_LOW_CYCLES) begin
                    state_d    = START_HIGH;
                    cntTimer_d = 24'd0;
                    dataDir_d  = 1'b0; // Release to High-Z
                end else begin
                    cntTimer_d = cntTimer + 1'b1;
                end
            end

            START_HIGH: begin
                if (wEdgeFalling) begin
                    state_d    = WAIT_LOW;
                    cntTimer_d = 24'd0;
                end else if (cntTimer >= LP_TIMEOUT_CYCLES) begin
                    state_d    = IDLE;
                end else begin
                    cntTimer_d = cntTimer + 1'b1;
                end
            end

            WAIT_LOW: begin
                if (wEdgeRising) begin
                    state_d    = WAIT_HIGH;
                    cntTimer_d = 24'd0;
                end else if (cntTimer >= LP_TIMEOUT_CYCLES) begin
                    state_d    = IDLE;
                end else begin
                    cntTimer_d = cntTimer + 1'b1;
                end
            end

            WAIT_HIGH: begin
                if (wEdgeFalling) begin
                    state_d    = READ_40BIT;
                    cntTimer_d = 24'd0;
                end else if (cntTimer >= LP_TIMEOUT_CYCLES) begin
                    state_d    = IDLE;
                end else begin
                    cntTimer_d = cntTimer + 1'b1;
                end
            end

            READ_40BIT: begin
                if (wEdgeRising) begin
                    cntTimer_d = 24'd0; // HIGH ??? ??? ??????? ?????
                end else if (wEdgeFalling) begin
                    // HIGH ??? ??? ????????????0 ??? 1 ?????
                    if (cntTimer > LP_BIT_HIGH_THRESHOLD_CYC) begin
                        dataShift_d = {dataShift[38:0], 1'b1};
                    end else begin
                        dataShift_d = {dataShift[38:0], 1'b0};
                    end
                    
                    cntBit_d = cntBit + 1'b1;
                    if (cntBit == 6'd39) begin
                        state_d = CHECKSUM;
                    end
                end else begin
                    cntTimer_d = cntTimer + 1'b1;
                end
                
                if (cntTimer >= LP_TIMEOUT_CYCLES) begin
                    state_d = IDLE;
                end
            end

            CHECKSUM: begin
                state_d = DONE;
            end

            DONE: begin
                state_d = IDLE;
            end

            default: begin
                state_d = IDLE;
            end
        endcase
    end

    // ----------------------------------------------------
    // 5. Output Logic
    // ----------------------------------------------------
    wire [7:0] wHumiInt = dataShift[39:32];
    wire [7:0] wHumiDec = dataShift[31:24];
    wire [7:0] wTempInt = dataShift[23:16];
    wire [7:0] wTempDec = dataShift[15:8];
    wire [7:0] wChksum  = dataShift[7:0];
    
    wire [7:0] wCalcChksum = wHumiInt + wHumiDec + wTempInt + wTempDec;

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            oTemp <= 16'd0;
            oHumi <= 16'd0;
            oValid <= 1'b0;
        end else begin
            oValid <= 1'b0;

            if (state == CHECKSUM) begin
                if (wCalcChksum == wChksum) begin
                    oHumi <= {wHumiInt, wHumiDec};
                    oTemp <= {wTempInt, wTempDec};
                    oValid <= 1'b1;
                end
            end
        end
    end

endmodule

