/*
[MODULE_INFO_START]
Name: TOP
Role: Top-level SoC wrapper for the RV32I 5-stage CPU
Summary:
  - Instantiates Rv32iCore and owns the instruction ROM, data RAM, APB bridge, UART, GPIO, and interrupt controller
  - Keeps memory/peripheral wiring outside the CPU core so additional SoC targets can attach without changing the pipeline
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP #(
  parameter int unsigned P_CLK_HZ     = 100_000_000,
  parameter int unsigned P_UART_BAUD  = 9_600,
  parameter int unsigned P_GPIO_WIDTH = 8
) (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic                    iUartRx,
  input  logic [P_GPIO_WIDTH-1:0] iGpioIn,
  input  logic                    iI2cSdaIn,
  input  logic                    iSpiMiso,

  output logic                    oUartTx,
  output logic [P_GPIO_WIDTH-1:0] oGpioOut,
  output logic [P_GPIO_WIDTH-1:0] oGpioOe,
  output logic                    oI2cScl,
  output logic                    oI2cSdaOut,
  output logic                    oI2cSdaOe,
  output logic                    oSpiSclk,
  output logic                    oSpiMosi,
  output logic                    oSpiCsN,
  output logic [6:0]              oSeg,
  output logic                    oDp,
  output logic [3:0]              oDigitSel,
  output logic                    oTimingProbe
);

  import rv32i_pkg::*;

  InstrBusReq_t InstrBusReq;
  InstrBusRsp_t InstrBusRsp;
  DataBusReq_t  DataBusReq;
  DataBusRsp_t  DataBusRsp;

  logic        RamSel;
  logic        RamWrEn;
  logic        ApbSel;
  logic        ApbWrite;
  logic        ApbPwrite;
  logic        ApbPenable;
  logic [31:0] BusAddr;
  logic [3:0]  BusByteEn;
  logic [31:0] BusWdata;
  logic [31:0] RamRdWord;
  logic [31:0] InstrRdWord;
  logic [31:0] ApbPrdata;
  logic        ApbRspReady;
  logic        ApbPslverr;
  logic [11:0] ApbPaddr;
  logic [3:0]  ApbPstrb;
  logic [31:0] ApbPwdata;
  logic        UartPsel;
  logic        GpioPsel;
  logic        I2cPsel;
  logic        IntcPsel;
  logic        SpiPsel;
  logic        FndPsel;
  logic [31:0] UartPrdata;
  logic [31:0] GpioPrdata;
  logic [31:0] I2cPrdata;
  logic [31:0] IntcPrdata;
  logic [31:0] SpiPrdata;
  logic [31:0] FndPrdata;
  logic        UartPready;
  logic        GpioPready;
  logic        I2cPready;
  logic        IntcPready;
  logic        SpiPready;
  logic        FndPready;
  logic        UartPslverr;
  logic        GpioPslverr;
  logic        I2cPslverr;
  logic        IntcPslverr;
  logic        SpiPslverr;
  logic        FndPslverr;

  logic        UartIrq;
  logic        GpioIrq;
  logic        I2cEventIrq;
  logic        I2cErrorIrq;
  logic        SpiEventIrq;
  logic        SpiErrorIrq;
  logic [LP_INTC_NUM_SOURCES-1:0] IntcIrqVec;
  logic        ExtIrqPending;
  logic        IntcVectorValid;
  logic [31:0] IntcVectorPc;
  logic [31:0] IntcSelectedSourceId;

  assign InstrBusRsp.RspRdata = InstrRdWord;

  Rv32iCore uRv32iCore (
    .iClk          (iClk),
    .iRstn         (iRstn),
    .iInstrBusRsp  (InstrBusRsp),
    .iDataBusRsp   (DataBusRsp),
    .iExtIrqPending(ExtIrqPending),
    .iIntcVectorValid(IntcVectorValid),
    .iIntcVectorPc (IntcVectorPc),
    .oInstrBusReq  (InstrBusReq),
    .oDataBusReq   (DataBusReq),
    .oTimingProbe  (oTimingProbe)
  );

  InstrRom uInstrRom (
    .iAddr  (InstrBusReq.ReqAddr),
    .oInstr (InstrRdWord)
  );

  DataBusMaster uDataBusMaster (
    .iReq     (DataBusReq),
    .iRamRdata(RamRdWord),
    .iApbRdata(ApbPrdata),
    .iApbReady(ApbRspReady),
    .iApbErr  (ApbPslverr),
    .oRamSel  (RamSel),
    .oRamWrEn (RamWrEn),
    .oApbSel  (ApbSel),
    .oApbWrite(ApbWrite),
    .oAddr    (BusAddr),
    .oByteEn  (BusByteEn),
    .oWdata   (BusWdata),
    .oRsp     (DataBusRsp)
  );

  DataRam uDataRam (
    .iClk    (iClk),
    .iWrEn   (RamWrEn),
    .iByteEn (BusByteEn),
    .iAddr   (BusAddr),
    .iWrData (BusWdata),
    .oRdWord (RamRdWord)
  );

  APBMASTER uAPBMASTER (
    .iClk         (iClk),
    .iRstn        (iRstn),
    .iApbSel      (ApbSel),
    .iPwrite      (ApbWrite),
    .iPaddr       (BusAddr),
    .iPstrb       (BusByteEn),
    .iPwdata      (BusWdata),
    .iUartPrdata  (UartPrdata),
    .iGpioPrdata  (GpioPrdata),
    .iI2cPrdata   (I2cPrdata),
    .iIntcPrdata  (IntcPrdata),
    .iSpiPrdata   (SpiPrdata),
    .iFndPrdata   (FndPrdata),
    .iUartPready  (UartPready),
    .iGpioPready  (GpioPready),
    .iI2cPready   (I2cPready),
    .iIntcPready  (IntcPready),
    .iSpiPready   (SpiPready),
    .iFndPready   (FndPready),
    .iUartPslverr (UartPslverr),
    .iGpioPslverr (GpioPslverr),
    .iI2cPslverr  (I2cPslverr),
    .iIntcPslverr (IntcPslverr),
    .iSpiPslverr  (SpiPslverr),
    .iFndPslverr  (FndPslverr),
    .oPwrite      (ApbPwrite),
    .oPaddr       (ApbPaddr),
    .oPstrb       (ApbPstrb),
    .oPwdata      (ApbPwdata),
    .oPenable     (ApbPenable),
    .oUartPsel    (UartPsel),
    .oGpioPsel    (GpioPsel),
    .oI2cPsel     (I2cPsel),
    .oIntcPsel    (IntcPsel),
    .oSpiPsel     (SpiPsel),
    .oFndPsel     (FndPsel),
    .oRspReady    (ApbRspReady),
    .oPrdata      (ApbPrdata),
    .oPslverr     (ApbPslverr)
  );

  APB_UART #(
    .P_CLK_HZ (P_CLK_HZ),
    .P_BAUD   (P_UART_BAUD)
  ) uAPB_UART (
    .iClk    (iClk),
    .iRstn   (iRstn),
    .iPsel   (UartPsel),
    .iPenable(ApbPenable),
    .iPwrite (ApbPwrite),
    .iPaddr  (ApbPaddr),
    .iPstrb  (ApbPstrb),
    .iPwdata (ApbPwdata),
    .iUartRx (iUartRx),
    .oPrdata (UartPrdata),
    .oPready (UartPready),
    .oPslverr(UartPslverr),
    .oUartTx (oUartTx),
    .oIrq    (UartIrq)
  );

  APB_GPIO #(
    .P_GPIO_WIDTH (P_GPIO_WIDTH)
  ) uAPB_GPIO (
    .iClk    (iClk),
    .iRstn   (iRstn),
    .iPsel   (GpioPsel),
    .iPenable(ApbPenable),
    .iPwrite (ApbPwrite),
    .iPaddr  (ApbPaddr),
    .iPstrb  (ApbPstrb),
    .iPwdata (ApbPwdata),
    .iGpioIn (iGpioIn),
    .oPrdata (GpioPrdata),
    .oPready (GpioPready),
    .oPslverr(GpioPslverr),
    .oGpioOut(oGpioOut),
    .oGpioOe (oGpioOe),
    .oIrq    (GpioIrq)
  );

  APB_I2C uAPB_I2C (
    .iClk     (iClk),
    .iRstn    (iRstn),
    .iPsel    (I2cPsel),
    .iPenable (ApbPenable),
    .iPwrite  (ApbPwrite),
    .iPaddr   (ApbPaddr),
    .iPstrb   (ApbPstrb),
    .iPwdata  (ApbPwdata),
    .iSdaIn   (iI2cSdaIn),
    .oPrdata  (I2cPrdata),
    .oPready  (I2cPready),
    .oPslverr (I2cPslverr),
    .oScl     (oI2cScl),
    .oSdaOut  (oI2cSdaOut),
    .oSdaOe   (oI2cSdaOe),
    .oEventIrq(I2cEventIrq),
    .oErrorIrq(I2cErrorIrq)
  );

  APB_SPI uAPB_SPI (
    .iClk     (iClk),
    .iRstn    (iRstn),
    .iPsel    (SpiPsel),
    .iPenable (ApbPenable),
    .iPwrite  (ApbPwrite),
    .iPaddr   (ApbPaddr),
    .iPstrb   (ApbPstrb),
    .iPwdata  (ApbPwdata),
    .iMiso    (iSpiMiso),
    .oPrdata  (SpiPrdata),
    .oPready  (SpiPready),
    .oPslverr (SpiPslverr),
    .oSclk    (oSpiSclk),
    .oMosi    (oSpiMosi),
    .oCsN     (oSpiCsN),
    .oEventIrq(SpiEventIrq),
    .oErrorIrq(SpiErrorIrq)
  );

  APB_FND #(
    .P_CLK_HZ (P_CLK_HZ)
  ) uAPB_FND (
    .iClk     (iClk),
    .iRstn    (iRstn),
    .iPsel    (FndPsel),
    .iPenable (ApbPenable),
    .iPwrite  (ApbPwrite),
    .iPaddr   (ApbPaddr),
    .iPstrb   (ApbPstrb),
    .iPwdata  (ApbPwdata),
    .oPrdata  (FndPrdata),
    .oPready  (FndPready),
    .oPslverr (FndPslverr),
    .oSeg     (oSeg),
    .oDp      (oDp),
    .oDigitSel(oDigitSel)
  );

  always_comb begin
    IntcIrqVec = '0;
    IntcIrqVec[LP_INTC_SRC_GPIO-1]      = GpioIrq;
    IntcIrqVec[LP_INTC_SRC_UART_RX-1]   = UartIrq;
    IntcIrqVec[LP_INTC_SRC_I2C_EVENT-1] = I2cEventIrq;
    IntcIrqVec[LP_INTC_SRC_I2C_ERROR-1] = I2cErrorIrq;
    IntcIrqVec[LP_INTC_SRC_SPI_EVENT-1] = SpiEventIrq;
    IntcIrqVec[LP_INTC_SRC_SPI_ERROR-1] = SpiErrorIrq;
  end

  InterruptController #(
    .P_NUM_SOURCES    (LP_INTC_NUM_SOURCES),
    .P_PRIORITY_WIDTH (LP_INTC_PRIORITY_WIDTH)
  ) uInterruptController (
    .iClk          (iClk),
    .iRstn         (iRstn),
    .iPsel         (IntcPsel),
    .iPenable      (ApbPenable),
    .iPwrite       (ApbPwrite),
    .iPaddr        (ApbPaddr),
    .iPstrb        (ApbPstrb),
    .iPwdata       (ApbPwdata),
    .iIrqVec       (IntcIrqVec),
    .oPrdata       (IntcPrdata),
    .oPready       (IntcPready),
    .oPslverr      (IntcPslverr),
    .oVectorValid  (IntcVectorValid),
    .oVectorPc     (IntcVectorPc),
    .oSelectedSourceId(IntcSelectedSourceId),
    .oMachineExtIrq(ExtIrqPending)
  );

endmodule
