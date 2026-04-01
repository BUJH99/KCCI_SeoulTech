/*
[MODULE_INFO_START]
Name: TOP
Role: Softmax accelerator top wrapper
Summary:
  - Connects the stream pipeline stages
  - Keeps all top-level interconnect in simple wrapper logic
[MODULE_INFO_END]
*/
`timescale 1ns/1ps
module TOP #(
    parameter integer P_C_MAX  = 1024,
    parameter integer P_ADDR_W = 10
)(
    input  wire         iClk,
    input  wire         iRstn,
    input  wire         iSAxisValid,
    output wire         oSAxisReady,
    input  wire [31:0]  iSAxisData,
    input  wire         iSAxisLast,
    input  wire [3:0]   iSAxisKeep,
    output wire         oMAxisValid,
    input  wire         iMAxisReady,
    output wire [31:0]  oMAxisData,
    output wire         oMAxisLast,
    output wire [3:0]   oMAxisKeep
);
    // Downscale -> shared fanout channel for ExpSum and Sub.
    wire        wDownscale2Fanout_Valid;
    wire        wDownscale2Fanout_Ready;
    wire [15:0] wDownscale2Fanout_Data;
    wire        wDownscale2Fanout_Last;

    wire        wDownscale2ExpSum_Ready;
    wire        wDownscale2Sub_Ready;
    wire        wDownscale2Fanout_Handshake;

    // ExpSum -> Sum.
    wire        wExpSum2Sum_Valid;
    wire        wExpSum2Sum_Ready;
    wire [15:0] wExpSum2Sum_Data;
    wire        wExpSum2Sum_Last;

    // Sum -> Ln.
    wire        wSum2Ln_Valid;
    wire        wSum2Ln_Ready;
    wire [15:0] wSum2Ln_Data;

    // Ln -> Sub.
    wire        wLn2Sub_Valid;
    wire        wLn2Sub_Ready;
    wire        wLn2Sub_Handshake;
    wire [15:0] wLn2Sub_Data;

    // Sub -> ExpOut.
    wire        wSub2ExpOut_Valid;
    wire        wSub2ExpOut_Ready;
    wire [15:0] wSub2ExpOut_Data;
    wire        wSub2ExpOut_Last;

    // ExpOut -> U16ToFp32.
    wire        wExpOut2U16ToFp32_Valid;
    wire        wExpOut2U16ToFp32_Ready;
    wire [15:0] wExpOut2U16ToFp32_Data;
    wire        wExpOut2U16ToFp32_Last;

    // Input keep is ignored because the accelerator consumes full 32-bit words.
    assign oMAxisKeep        = 4'hF;
    assign wDownscale2Fanout_Ready = wDownscale2ExpSum_Ready & wDownscale2Sub_Ready;
    assign wDownscale2Fanout_Handshake = wDownscale2Fanout_Valid & wDownscale2Fanout_Ready;
    assign wLn2Sub_Handshake = wLn2Sub_Valid & wLn2Sub_Ready;

    Downscale #(
        .P_C_MAX (P_C_MAX),
        .P_ADDR_W(P_ADDR_W)
    ) uDownscale (
        .iClk   (iClk),
        .iRstn  (iRstn),
        .iSValid(iSAxisValid),
        .oSReady(oSAxisReady),
        .iSData (iSAxisData),
        .iSLast (iSAxisLast),
        .oMValid(wDownscale2Fanout_Valid),
        .iMReady(wDownscale2Fanout_Ready),
        .oMData (wDownscale2Fanout_Data),
        .oMLast (wDownscale2Fanout_Last)
    );

    ExpSum uExpSum (
        .iClk  (iClk),
        .iRstn (iRstn),
        .iValid(wDownscale2Fanout_Handshake),
        .oReady(wDownscale2ExpSum_Ready),
        .iLast (wDownscale2Fanout_Last),
        .iData (wDownscale2Fanout_Data),
        .oValid(wExpSum2Sum_Valid),
        .iReady(wExpSum2Sum_Ready),
        .oLast (wExpSum2Sum_Last),
        .oData (wExpSum2Sum_Data)
    );

    Sum uSum (
        .iClk  (iClk),
        .iRstn (iRstn),
        .iValid(wExpSum2Sum_Valid),
        .oReady(wExpSum2Sum_Ready),
        .iLast (wExpSum2Sum_Last),
        .iData (wExpSum2Sum_Data),
        .oValid(wSum2Ln_Valid),
        .iReady(wSum2Ln_Ready),
        .oData (wSum2Ln_Data)
    );

    Ln uLn (
        .iClk  (iClk),
        .iRstn (iRstn),
        .iValid(wSum2Ln_Valid),
        .oReady(wSum2Ln_Ready),
        .iData (wSum2Ln_Data),
        .oValid(wLn2Sub_Valid),
        .iReady(wLn2Sub_Ready),
        .oData (wLn2Sub_Data)
    );

    Sub #(
        .P_C_MAX (P_C_MAX),
        .P_ADDR_W(P_ADDR_W)
    ) uSub (
        .iClk        (iClk),
        .iRstn       (iRstn),
        .iVectorData (wDownscale2Fanout_Data),
        .iVectorValid(wDownscale2Fanout_Handshake),
        .iVectorLast (wDownscale2Fanout_Last),
        .oVectorReady(wDownscale2Sub_Ready),
        .iScalarData (wLn2Sub_Data),
        .iScalarValid(wLn2Sub_Handshake),
        .oScalarReady(wLn2Sub_Ready),
        .oData       (wSub2ExpOut_Data),
        .oDataValid  (wSub2ExpOut_Valid),
        .iDataReady  (wSub2ExpOut_Ready),
        .oDataLast   (wSub2ExpOut_Last)
    );

    ExpOut uExpOut (
        .iClk  (iClk),
        .iRstn (iRstn),
        .iValid(wSub2ExpOut_Valid),
        .oReady(wSub2ExpOut_Ready),
        .iLast (wSub2ExpOut_Last),
        .iData (wSub2ExpOut_Data),
        .oValid(wExpOut2U16ToFp32_Valid),
        .iReady(wExpOut2U16ToFp32_Ready),
        .oLast (wExpOut2U16ToFp32_Last),
        .oData (wExpOut2U16ToFp32_Data)
    );

    U16ToFp32 uU16ToFp32 (
        .iClk   (iClk),
        .iRstn  (iRstn),
        .iSValid(wExpOut2U16ToFp32_Valid),
        .oSReady(wExpOut2U16ToFp32_Ready),
        .iSData (wExpOut2U16ToFp32_Data),
        .iSLast (wExpOut2U16ToFp32_Last),
        .oMValid(oMAxisValid),
        .iMReady(iMAxisReady),
        .oMData (oMAxisData),
        .oMLast (oMAxisLast)
    );
endmodule
