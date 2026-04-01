/*
[MODULE_INFO_START]
Name: DataRam
Role: Data memory wrapper
Summary:
  - Provides word-oriented storage for RV32I load/store behavior
  - Separates misalignment qualification from architectural readback gating
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module DataRam #(
  parameter int unsigned P_ADDR_WIDTH = 8,
  parameter int unsigned P_DATA_WIDTH = 32
)(
  input  logic                    iClk,
  input  logic                    iMemRead,
  input  logic                    iWrEn,
  input  rv32i_pkg::mem_size_e    iMemSize,
  input  logic                    iLoadUnsigned,
  input  logic [31:0]             iAddr,
  input  logic [P_DATA_WIDTH-1:0] iWrData,
  output logic [P_DATA_WIDTH-1:0] oRdData,
  output logic                    oMisaligned
);

  localparam int unsigned LP_DEPTH = (1 << P_ADDR_WIDTH);

  (* ram_style = "distributed" *) logic [P_DATA_WIDTH-1:0] memRam [0:LP_DEPTH-1];
  logic [P_ADDR_WIDTH-1:0] wordAddr;
  logic [31:0]             rdWord;
  logic [7:0]              rdByte;
  logic [15:0]             rdHalf;
  logic [31:0]             rdDataRaw;
  logic                    loadMisaligned;
  logic                    storeMisaligned;

  assign wordAddr = iAddr[P_ADDR_WIDTH+1:2];
  assign rdWord  = memRam[wordAddr];

  always_comb begin
    rdByte = rdWord[7:0];

    unique case (iAddr[1:0])
      2'd0:    rdByte = rdWord[7:0];
      2'd1:    rdByte = rdWord[15:8];
      2'd2:    rdByte = rdWord[23:16];
      2'd3:    rdByte = rdWord[31:24];
      default: rdByte = rdWord[7:0];
    endcase
  end

  always_comb begin
    rdHalf = rdWord[15:0];

    unique case (iAddr[1])
      1'b0:    rdHalf = rdWord[15:0];
      1'b1:    rdHalf = rdWord[31:16];
      default: rdHalf = rdWord[15:0];
    endcase
  end

  always_comb begin
    loadMisaligned  = 1'b0;
    storeMisaligned = 1'b0;

    if (iMemRead) begin
      unique case (iMemSize)
        rv32i_pkg::MEM_BYTE: loadMisaligned = 1'b0;
        rv32i_pkg::MEM_HALF: loadMisaligned = iAddr[0];
        rv32i_pkg::MEM_WORD: loadMisaligned = (iAddr[1:0] != 2'b00);
        default:             loadMisaligned = 1'b0;
      endcase
    end

    if (iWrEn) begin
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
    rdDataRaw = rdWord;

    unique case (iMemSize)
      rv32i_pkg::MEM_BYTE: begin
        if (iLoadUnsigned) begin
          rdDataRaw = {24'd0, rdByte};
        end else begin
          rdDataRaw = {{24{rdByte[7]}}, rdByte};
        end
      end
      rv32i_pkg::MEM_HALF: begin
        if (iLoadUnsigned) begin
          rdDataRaw = {16'd0, rdHalf};
        end else begin
          rdDataRaw = {{16{rdHalf[15]}}, rdHalf};
        end
      end
      rv32i_pkg::MEM_WORD: begin
        rdDataRaw = rdWord;
      end
      default: begin
        rdDataRaw = rdWord;
      end
    endcase
  end

  assign oRdData = rdDataRaw;

  always_ff @(posedge iClk) begin
    if (iWrEn && !storeMisaligned) begin
      unique case (iMemSize)
        rv32i_pkg::MEM_BYTE: begin
          memRam[wordAddr][(iAddr[1:0] * 8) +: 8] <= iWrData[7:0];
        end
        rv32i_pkg::MEM_HALF: begin
          memRam[wordAddr][(iAddr[1] * 16) +: 16] <= iWrData[15:0];
        end
        rv32i_pkg::MEM_WORD: begin
          memRam[wordAddr] <= iWrData;
        end
        default: begin
          memRam[wordAddr] <= iWrData;
        end
      endcase
    end
  end

endmodule
