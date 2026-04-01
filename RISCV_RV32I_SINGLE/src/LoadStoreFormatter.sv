/*
[MODULE_INFO_START]
Name: LoadStoreFormatter
Role: Load/store byte-lane formatter for the data-bus path
Summary:
  - Builds aligned write data and byte enables for byte/half/word stores
  - Formats word readback into RV32I architectural load results and flags misalignment
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module LoadStoreFormatter (
  input  rv32i_pkg::bus_cmd_e     iBusCmd,
  input  rv32i_pkg::mem_size_e    iMemSize,
  input  logic                    iLoadUnsigned,
  input  logic [31:0]             iAddr,
  input  logic [31:0]             iStoreData,
  input  logic [31:0]             iLoadDataRaw,
  output logic [3:0]              oStoreByteEn,
  output logic [31:0]             oStoreDataAligned,
  output logic [31:0]             oLoadData,
  output logic                    oMisaligned
);

  logic [7:0]  loadByte;
  logic [15:0] loadHalf;
  logic        loadMisaligned;
  logic        storeMisaligned;

  always_comb begin
    unique case (iAddr[1:0])
      2'd0:    loadByte = iLoadDataRaw[7:0];
      2'd1:    loadByte = iLoadDataRaw[15:8];
      2'd2:    loadByte = iLoadDataRaw[23:16];
      2'd3:    loadByte = iLoadDataRaw[31:24];
      default: loadByte = iLoadDataRaw[7:0];
    endcase
  end

  always_comb begin
    unique case (iAddr[1])
      1'b0:    loadHalf = iLoadDataRaw[15:0];
      1'b1:    loadHalf = iLoadDataRaw[31:16];
      default: loadHalf = iLoadDataRaw[15:0];
    endcase
  end

  always_comb begin
    loadMisaligned  = 1'b0;
    storeMisaligned = 1'b0;

    if (iBusCmd == rv32i_pkg::BUS_CMD_READ) begin
      unique case (iMemSize)
        rv32i_pkg::MEM_BYTE: loadMisaligned = 1'b0;
        rv32i_pkg::MEM_HALF: loadMisaligned = iAddr[0];
        rv32i_pkg::MEM_WORD: loadMisaligned = (iAddr[1:0] != 2'b00);
        default:             loadMisaligned = 1'b0;
      endcase
    end

    if (iBusCmd == rv32i_pkg::BUS_CMD_WRITE) begin
      unique case (iMemSize)
        rv32i_pkg::MEM_BYTE: storeMisaligned = 1'b0;
        rv32i_pkg::MEM_HALF: storeMisaligned = iAddr[0];
        rv32i_pkg::MEM_WORD: storeMisaligned = (iAddr[1:0] != 2'b00);
        default:             storeMisaligned = 1'b0;
      endcase
    end
  end

  assign oMisaligned = loadMisaligned || storeMisaligned;

  always_comb begin
    oStoreByteEn      = '0;
    oStoreDataAligned = '0;

    if (iBusCmd == rv32i_pkg::BUS_CMD_WRITE) begin
      unique case (iMemSize)
        rv32i_pkg::MEM_BYTE: begin
          oStoreByteEn      = 4'b0001 << iAddr[1:0];
          oStoreDataAligned = {24'd0, iStoreData[7:0]} << (iAddr[1:0] * 8);
        end
        rv32i_pkg::MEM_HALF: begin
          if (!iAddr[0]) begin
            oStoreByteEn      = iAddr[1] ? 4'b1100 : 4'b0011;
            oStoreDataAligned = {16'd0, iStoreData[15:0]} << (iAddr[1] ? 16 : 0);
          end
        end
        rv32i_pkg::MEM_WORD: begin
          if (iAddr[1:0] == 2'b00) begin
            oStoreByteEn      = 4'b1111;
            oStoreDataAligned = iStoreData;
          end
        end
        default: begin
          oStoreByteEn      = '0;
          oStoreDataAligned = '0;
        end
      endcase
    end
  end

  always_comb begin
    oLoadData = iLoadDataRaw;

    unique case (iMemSize)
      rv32i_pkg::MEM_BYTE: begin
        if (iLoadUnsigned) begin
          oLoadData = {24'd0, loadByte};
        end else begin
          oLoadData = {{24{loadByte[7]}}, loadByte};
        end
      end
      rv32i_pkg::MEM_HALF: begin
        if (iLoadUnsigned) begin
          oLoadData = {16'd0, loadHalf};
        end else begin
          oLoadData = {{16{loadHalf[15]}}, loadHalf};
        end
      end
      rv32i_pkg::MEM_WORD: begin
        oLoadData = iLoadDataRaw;
      end
      default: begin
        oLoadData = iLoadDataRaw;
      end
    endcase
  end

endmodule
