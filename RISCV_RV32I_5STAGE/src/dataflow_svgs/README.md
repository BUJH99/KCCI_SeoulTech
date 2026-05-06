# Dataflow SVG Set

Generated from pipeline_block_diagram.svg using RTL-based instruction-class grouping.

Each SVG includes:
- numbered circle badges on the main module steps
- matching numbered pill badges on the key signal segments
- a step list box that follows the same 1 -> N flow order

- pipeline_block_diagram_top_view.svg: Extended TOP-level copy of pipeline_block_diagram.svg with external bus, APB, UART, GPIO, interrupt-controller, and pin-level modules
- pipeline_dataflow_rtype_alu.svg: R-Type ALU - ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND
- pipeline_dataflow_opimm_alu.svg: I-Type ALU - ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI
- pipeline_dataflow_load.svg: Load - LB/LH/LW/LBU/LHU
- pipeline_dataflow_store.svg: Store - SB/SH/SW
- pipeline_dataflow_branch.svg: Branch - BEQ/BNE/BLT/BGE/BLTU/BGEU
- pipeline_dataflow_upper_imm.svg: Upper Immediate - LUI / AUIPC
- pipeline_dataflow_jal.svg: JAL - Decode redirect + link write-back
- pipeline_dataflow_jalr.svg: JALR - EX redirect + link write-back
- pipeline_dataflow_csr.svg: CSR Access - CSRRW / CSRRS / CSRRC (+ immediate variants)
- pipeline_dataflow_mret.svg: MRET - Return to mepc through EX redirect
- pipeline_dataflow_trap_entry.svg: Trap Entry - Illegal / ECALL / EBREAK / misalign / access fault
- pipeline_dataflow_interrupt_trap.svg: Interrupt / Trap Flow - peripheral IRQ, INTC claim/complete, CSR gate, trap entry, handler, and MRET

Note: FENCE/MISC-MEM is treated as a datapath NOP in SystemDecoder, so it is not split into a separate special-path SVG.
