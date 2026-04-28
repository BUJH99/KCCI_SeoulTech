`timescale 1ns / 1ps

module tb_TOP;

  logic        iClk100Mhz;
  logic        iRst;
  logic [15:0] iSw;
  wire  [15:0] oLed;
  logic        iJaCs;
  logic        iJaMosi;
  wire         oJaMiso;
  logic        iJaSclk;
  tri1         ioJbScl;
  tri1         ioJbSda;
  logic        I2cMasterSclDriveLow;
  logic        I2cMasterDriveLow;

  assign ioJbScl = I2cMasterSclDriveLow ? 1'b0 : 1'bz;
  assign ioJbSda = I2cMasterDriveLow ? 1'b0 : 1'bz;

  TOP dut (
    .iClk100Mhz(iClk100Mhz),
    .iRst      (iRst),
    .iSw       (iSw),
    .oLed      (oLed),
    .iJaCs     (iJaCs),
    .iJaMosi   (iJaMosi),
    .oJaMiso   (oJaMiso),
    .iJaSclk   (iJaSclk),
    .ioJbScl   (ioJbScl),
    .ioJbSda   (ioJbSda)
  );

  initial begin
    iClk100Mhz = 1'b0;
    forever #5 iClk100Mhz = ~iClk100Mhz;
  end

  initial begin
    iRst            = 1'b1;
    iSw             = '0;
    iJaCs           = 1'b1;
    iJaMosi         = 1'b0;
    iJaSclk         = 1'b0;
    I2cMasterSclDriveLow = 1'b0;
    I2cMasterDriveLow = 1'b0;
    repeat (8) @(posedge iClk100Mhz);
    iRst = 1'b0;
  end

  initial begin
    #300_000;
    $fatal(1, "tb_TOP timeout");
  end

  initial begin
    $dumpfile("serial_slave_tb.vcd");
    $dumpvars(0, tb_TOP);
  end

  task automatic SpiTransfer16(input logic [15:0] TxFrame, output logic [15:0] RxFrame);
    integer idx;
    begin
      RxFrame = '0;
      iJaCs   = 1'b1;
      iJaSclk = 1'b0;
      #400;
      iJaCs = 1'b0;
      for (idx = 15; idx >= 0; idx = idx - 1) begin
        iJaMosi = TxFrame[idx];
        #400;
        iJaSclk = 1'b1;
        RxFrame[idx] = oJaMiso;
        #400;
        iJaSclk = 1'b0;
      end
      #400;
      iJaCs = 1'b1;
      #800;
    end
  endtask

  task automatic I2cDelay;
    begin
      #1000;
    end
  endtask

  task automatic I2cDriveStart;
    begin
      I2cMasterDriveLow = 1'b0;
      I2cMasterSclDriveLow = 1'b0;
      I2cDelay();
      I2cMasterDriveLow = 1'b1;
      I2cDelay();
      I2cMasterSclDriveLow = 1'b1;
      I2cDelay();
    end
  endtask

  task automatic I2cDriveStop;
    begin
      I2cMasterDriveLow = 1'b1;
      I2cDelay();
      I2cMasterSclDriveLow = 1'b0;
      I2cDelay();
      I2cMasterDriveLow = 1'b0;
      I2cDelay();
    end
  endtask

  task automatic I2cWriteBit(input logic BitValue);
    begin
      I2cMasterSclDriveLow = 1'b1;
      I2cMasterDriveLow = !BitValue;
      I2cDelay();
      I2cMasterSclDriveLow = 1'b0;
      I2cDelay();
      I2cMasterSclDriveLow = 1'b1;
      I2cDelay();
    end
  endtask

  task automatic I2cReadBit(output logic BitValue);
    begin
      I2cMasterSclDriveLow = 1'b1;
      I2cMasterDriveLow = 1'b0;
      I2cDelay();
      I2cMasterSclDriveLow = 1'b0;
      #500;
      BitValue = ioJbSda;
      #500;
      I2cMasterSclDriveLow = 1'b1;
      I2cDelay();
    end
  endtask

  task automatic I2cWriteByte(input logic [7:0] ByteData, output logic AckSeen);
    integer idx;
    logic AckBit;
    begin
      for (idx = 7; idx >= 0; idx = idx - 1) begin
        I2cWriteBit(ByteData[idx]);
      end
      I2cReadBit(AckBit);
      AckSeen = (AckBit == 1'b0);
    end
  endtask

  task automatic I2cReadByte(output logic [7:0] ByteData, input logic SendNack);
    integer idx;
    logic BitValue;
    begin
      for (idx = 7; idx >= 0; idx = idx - 1) begin
        I2cReadBit(BitValue);
        ByteData[idx] = BitValue;
      end
      I2cWriteBit(SendNack);
    end
  endtask

  initial begin : test_proc
    logic [15:0] SpiRxFrame;
    logic [7:0]  I2cReadValue;
    logic        AckSeen;

    wait (!iRst);

    iSw[15]   = 1'b0;
    iSw[14:8] = 7'h25;

    SpiTransfer16({1'b0, 7'h01, 8'h34}, SpiRxFrame);
    wait (oLed[6:0] == 7'h34);

    SpiTransfer16({1'b1, 7'h02, 8'h00}, SpiRxFrame);
    if (SpiRxFrame[7:0] !== 8'h25) $fatal(1, "SPI readback mismatch: %02h", SpiRxFrame[7:0]);

    iSw[15]   = 1'b1;
    iSw[14:8] = 7'h3A;

    I2cDriveStart();
    I2cWriteByte({7'h5A, 1'b0}, AckSeen);
    if (!AckSeen) $fatal(1, "I2C device address write ACK missing");
    I2cWriteByte(8'h01, AckSeen);
    if (!AckSeen) $fatal(1, "I2C register write ACK missing");
    I2cWriteByte(8'h1C, AckSeen);
    if (!AckSeen) $fatal(1, "I2C data write ACK missing");
    I2cDriveStop();
    wait (oLed[6:0] == 7'h1C);

    I2cDriveStart();
    I2cWriteByte({7'h5A, 1'b0}, AckSeen);
    if (!AckSeen) $fatal(1, "I2C read address(W) ACK missing");
    I2cWriteByte(8'h02, AckSeen);
    if (!AckSeen) $fatal(1, "I2C read register ACK missing");
    I2cDriveStart();
    I2cWriteByte({7'h5A, 1'b1}, AckSeen);
    if (!AckSeen) $fatal(1, "I2C read address(R) ACK missing");
    I2cReadByte(I2cReadValue, 1'b1);
    I2cDriveStop();

    if (I2cReadValue !== 8'h3A) $fatal(1, "I2C readback mismatch: %02h", I2cReadValue);
    if (oLed[6:0] !== 7'h1C) $fatal(1, "I2C read sequence unexpectedly changed LED register: %02h", oLed[6:0]);

    repeat (20) @(posedge iClk100Mhz);
    $display("tb_TOP PASS");
    $finish;
  end

endmodule
