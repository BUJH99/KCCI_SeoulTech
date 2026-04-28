`timescale 1ns / 1ps

module tb_TOP;

  localparam int unsigned LP_POLL_CYCLES = 300;
  localparam int unsigned LP_SPI_DIV     = 20;
  localparam int unsigned LP_I2C_DIV     = 40;

  logic        iClk100Mhz;
  logic        iRst;
  logic [15:0] iSw;
  wire  [15:0] oLed;
  wire         oJaCs;
  wire         oJaMosi;
  logic        iJaMiso;
  wire         oJaSclk;
  tri1         ioJbScl;
  tri1         ioJbSda;
  logic        I2cSlaveDriveLow;

  logic [7:0]  SpiReadData;
  logic [7:0]  SpiLastWriteData;
  logic        SpiWriteSeen;
  logic        SpiReadMode;
  integer      SpiBitCnt;
  logic [15:0] SpiShiftIn;
  logic [7:0]  SpiShiftOut;

  logic [7:0]  I2cReadData;
  logic [7:0]  I2cLastWriteData;
  logic        I2cWriteSeen;

  assign ioJbSda = I2cSlaveDriveLow ? 1'b0 : 1'bz;

  TOP #(
    .P_POLL_CYCLES(LP_POLL_CYCLES),
    .P_SPI_DIV    (LP_SPI_DIV),
    .P_I2C_DIV    (LP_I2C_DIV)
  ) dut (
    .iClk100Mhz(iClk100Mhz),
    .iRst      (iRst),
    .iSw       (iSw),
    .oLed      (oLed),
    .oJaCs     (oJaCs),
    .oJaMosi   (oJaMosi),
    .iJaMiso   (iJaMiso),
    .oJaSclk   (oJaSclk),
    .ioJbScl   (ioJbScl),
    .ioJbSda   (ioJbSda)
  );

  initial begin
    iClk100Mhz = 1'b0;
    forever #5 iClk100Mhz = ~iClk100Mhz;
  end

  initial begin
    iRst             = 1'b1;
    iSw              = '0;
    iJaMiso          = 1'b0;
    I2cSlaveDriveLow = 1'b0;
    SpiReadData      = 8'h00;
    SpiLastWriteData = 8'h00;
    SpiWriteSeen     = 1'b0;
    SpiReadMode      = 1'b0;
    I2cReadData      = 8'h00;
    I2cLastWriteData = 8'h00;
    I2cWriteSeen     = 1'b0;
    repeat (8) @(posedge iClk100Mhz);
    iRst = 1'b0;
  end

  initial begin
    #200_000;
    $fatal(1, "tb_TOP timeout");
  end

  initial begin
    $dumpfile("serial_master_tb.vcd");
    $dumpvars(0, tb_TOP);
  end

  always @(negedge oJaCs) begin
    SpiBitCnt     = 0;
    SpiShiftIn    = '0;
    SpiShiftOut   = SpiReadData;
    SpiReadMode   = 1'b0;
    iJaMiso       = 1'b0;
  end

  always @(posedge oJaSclk) begin
    if (!oJaCs) begin
      SpiShiftIn = {SpiShiftIn[14:0], oJaMosi};
      SpiBitCnt  = SpiBitCnt + 1;
      if ((SpiBitCnt + 1) == 8) begin
        SpiReadMode = {SpiShiftIn[6:0], oJaMosi}[7];
      end
    end
  end

  always @(negedge oJaSclk) begin
    if (!oJaCs) begin
      if (SpiBitCnt < 8) begin
        iJaMiso = 1'b0;
      end else if (SpiReadMode) begin
        iJaMiso   = SpiShiftOut[7];
        SpiShiftOut = {SpiShiftOut[6:0], 1'b0};
      end else begin
        iJaMiso = 1'b0;
      end
    end
  end

  always @(posedge oJaCs) begin
    if (SpiBitCnt == 16) begin
      if (!SpiShiftIn[15] && (SpiShiftIn[14:8] == 7'h01)) begin
        SpiLastWriteData = SpiShiftIn[7:0];
        SpiWriteSeen     = 1'b1;
      end
    end
  end

  task automatic WaitI2cStart;
    begin : wait_start_loop
      forever begin
        @(negedge ioJbSda);
        if (ioJbScl === 1'b1) begin
          disable wait_start_loop;
        end
      end
    end
  endtask

  task automatic WaitI2cStop;
    begin : wait_stop_loop
      forever begin
        @(posedge ioJbSda);
        if (ioJbScl === 1'b1) begin
          disable wait_stop_loop;
        end
      end
    end
  endtask

  task automatic I2cReadByteFromMaster(output logic [7:0] ByteData);
    integer idx;
    begin
      for (idx = 7; idx >= 0; idx = idx - 1) begin
        @(posedge ioJbScl);
        ByteData[idx] = ioJbSda;
        @(negedge ioJbScl);
      end
    end
  endtask

  task automatic I2cDriveAck;
    begin
      I2cSlaveDriveLow = 1'b1;
      @(posedge ioJbScl);
      @(negedge ioJbScl);
      I2cSlaveDriveLow = 1'b0;
    end
  endtask

  task automatic I2cDriveReadByte(input logic [7:0] ByteData, output logic MasterNack);
    integer idx;
    begin
      for (idx = 7; idx >= 0; idx = idx - 1) begin
        I2cSlaveDriveLow = !ByteData[idx];
        @(posedge ioJbScl);
        @(negedge ioJbScl);
      end
      I2cSlaveDriveLow = 1'b0;
      @(posedge ioJbScl);
      MasterNack = (ioJbSda === 1'b1);
      @(negedge ioJbScl);
    end
  endtask

  task automatic I2cSlaveHandlePoll(input logic [7:0] ReadPayload);
    logic [7:0] ByteData;
    logic       MasterNack;
    begin
      WaitI2cStart();
      I2cReadByteFromMaster(ByteData);
      if (ByteData !== {7'h5A, 1'b0}) $fatal(1, "I2C write address mismatch: %02h", ByteData);
      I2cDriveAck();

      I2cReadByteFromMaster(ByteData);
      if (ByteData !== 8'h01) $fatal(1, "I2C write register mismatch: %02h", ByteData);
      I2cDriveAck();

      I2cReadByteFromMaster(ByteData);
      I2cLastWriteData = ByteData;
      I2cWriteSeen     = 1'b1;
      I2cDriveAck();
      WaitI2cStop();

      WaitI2cStart();
      I2cReadByteFromMaster(ByteData);
      if (ByteData !== {7'h5A, 1'b0}) $fatal(1, "I2C read address(W) mismatch: %02h", ByteData);
      I2cDriveAck();

      I2cReadByteFromMaster(ByteData);
      if (ByteData !== 8'h02) $fatal(1, "I2C read register mismatch: %02h", ByteData);
      I2cDriveAck();

      WaitI2cStart();
      I2cReadByteFromMaster(ByteData);
      if (ByteData !== {7'h5A, 1'b1}) $fatal(1, "I2C read address(R) mismatch: %02h", ByteData);
      I2cDriveAck();

      I2cDriveReadByte(ReadPayload, MasterNack);
      if (!MasterNack) $fatal(1, "Master did not NACK the final I2C read byte");
      WaitI2cStop();
    end
  endtask

  initial begin : test_proc
    wait (!iRst);

    iSw[15]   = 1'b0;
    iSw[6:0]  = 7'h12;
    SpiReadData = 8'h55;
    wait (SpiWriteSeen == 1'b1);
    if (SpiLastWriteData !== 8'h12) $fatal(1, "SPI write payload mismatch: %02h", SpiLastWriteData);
    wait (oLed[14:8] == SpiReadData[6:0]);

    SpiWriteSeen = 1'b0;
    I2cWriteSeen = 1'b0;
    iSw[15]      = 1'b1;
    iSw[6:0]     = 7'h2B;
    I2cReadData  = 8'h36;

    fork
      begin
        I2cSlaveHandlePoll(I2cReadData);
      end
    join_none

    wait (I2cWriteSeen == 1'b1);
    if (I2cLastWriteData !== 8'h2B) $fatal(1, "I2C write payload mismatch: %02h", I2cLastWriteData);
    wait (oLed[14:8] == I2cReadData[6:0]);

    repeat (20) @(posedge iClk100Mhz);
    $display("tb_TOP PASS");
    $finish;
  end

endmodule
