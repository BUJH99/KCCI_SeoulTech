/*
[MODULE_INFO_START]
Name: GpioRegs
Role: APB-facing GPIO register block for data, direction, and IRQ configuration state
Summary:
  - Stores the GPIO output, direction, rise-enable, and fall-enable registers
  - Implements APB readback, write decoding, and IRQ-status clear mask generation
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module GpioRegs #(
  parameter int unsigned P_GPIO_WIDTH = 8
) (
  input  logic                    iClk,
  input  logic                    iRstn,
  input  logic                    iAccessEn,
  input  logic                    iPwrite,
  input  logic [11:0]             iPaddr,
  input  logic [3:0]              iPstrb,
  input  logic [31:0]             iPwdata,
  input  logic [P_GPIO_WIDTH-1:0] iGpioIn,
  input  logic [P_GPIO_WIDTH-1:0] iIrqStatus,

  output logic [31:0]             oPrdata,
  output logic                    oPslverr,
  output logic [P_GPIO_WIDTH-1:0] oDataOut,
  output logic [P_GPIO_WIDTH-1:0] oDir,
  output logic [P_GPIO_WIDTH-1:0] oIrqRiseEn,
  output logic [P_GPIO_WIDTH-1:0] oIrqFallEn,
  output logic [P_GPIO_WIDTH-1:0] oIrqClrMask
);

  import rv32i_pkg::*;

  localparam logic [11:0] LP_REG_DATA_OUT    = 12'h000;
  localparam logic [11:0] LP_REG_DATA_IN     = 12'h004;
  localparam logic [11:0] LP_REG_DIR         = 12'h008;
  localparam logic [11:0] LP_REG_IRQ_RISE_EN = 12'h00C;
  localparam logic [11:0] LP_REG_IRQ_FALL_EN = 12'h010;
  localparam logic [11:0] LP_REG_IRQ_STATUS  = 12'h014;
  localparam int unsigned LP_PAD_WIDTH       = 32 - P_GPIO_WIDTH;

  logic [31:0] DataOutWord;
  logic [31:0] DirWord;
  logic [31:0] IrqRiseEnWord;
  logic [31:0] IrqFallEnWord;
  logic [31:0] IrqStatusWord;
  logic [31:0] IrqClrWord;
  logic [31:0] DataOutWriteWord;
  logic [31:0] DirWriteWord;
  logic [31:0] IrqRiseEnWriteWord;
  logic [31:0] IrqFallEnWriteWord;
  
  assign DataOutWord        = {{LP_PAD_WIDTH{1'b0}}, oDataOut};
  assign DirWord            = {{LP_PAD_WIDTH{1'b0}}, oDir};
  assign IrqRiseEnWord      = {{LP_PAD_WIDTH{1'b0}}, oIrqRiseEn};
  assign IrqFallEnWord      = {{LP_PAD_WIDTH{1'b0}}, oIrqFallEn};
  assign IrqStatusWord      = {{LP_PAD_WIDTH{1'b0}}, iIrqStatus};
  assign DataOutWriteWord   = ByteWriteMerge(DataOutWord, iPwdata, iPstrb);
  assign DirWriteWord       = ByteWriteMerge(DirWord, iPwdata, iPstrb);
  assign IrqRiseEnWriteWord = ByteWriteMerge(IrqRiseEnWord, iPwdata, iPstrb);
  assign IrqFallEnWriteWord = ByteWriteMerge(IrqFallEnWord, iPwdata, iPstrb);
  assign IrqClrWord         = ByteWriteMerge(32'd0, iPwdata, iPstrb);
  assign oIrqClrMask        = (iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_STATUS))
                            ? IrqClrWord[P_GPIO_WIDTH-1:0]
                            : '0;
  //READ
  always_comb begin
    oPrdata  = '0;
    oPslverr = 1'b0;

    if (iAccessEn) begin
      unique case (iPaddr)
        LP_REG_DATA_OUT: begin
          if (!iPwrite) begin
            oPrdata = DataOutWord;
          end
        end

        LP_REG_DATA_IN: begin
          if (iPwrite) begin
            oPslverr = 1'b1;
          end else begin
            oPrdata = {{LP_PAD_WIDTH{1'b0}}, iGpioIn};
          end
        end

        LP_REG_DIR: begin
          if (!iPwrite) begin
            oPrdata = DirWord;
          end
        end

        LP_REG_IRQ_RISE_EN: begin
          if (!iPwrite) begin
            oPrdata = IrqRiseEnWord;
          end
        end

        LP_REG_IRQ_FALL_EN: begin
          if (!iPwrite) begin
            oPrdata = IrqFallEnWord;
          end
        end

        LP_REG_IRQ_STATUS: begin
          oPrdata = IrqStatusWord;
        end

        default: begin
          oPslverr = 1'b1;
        end
      endcase
    end
  end

  //WRITE
  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      oDataOut   <= '0;
      oDir       <= '0;
      oIrqRiseEn <= '0;
      oIrqFallEn <= '0;
    end else begin
      if (iAccessEn && iPwrite && (iPaddr == LP_REG_DATA_OUT)) begin
        oDataOut <= DataOutWriteWord[P_GPIO_WIDTH-1:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_DIR)) begin
        oDir <= DirWriteWord[P_GPIO_WIDTH-1:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_RISE_EN)) begin
        oIrqRiseEn <= IrqRiseEnWriteWord[P_GPIO_WIDTH-1:0];
      end

      if (iAccessEn && iPwrite && (iPaddr == LP_REG_IRQ_FALL_EN)) begin
        oIrqFallEn <= IrqFallEnWriteWord[P_GPIO_WIDTH-1:0];
      end
    end
  end

endmodule
