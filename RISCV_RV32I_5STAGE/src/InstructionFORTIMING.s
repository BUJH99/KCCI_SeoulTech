# =============================================================================
# RV32I single-cycle timing / golden-check program
#   - Check the GOLDEN field after each instruction retires.
#   - RFCHK   : Regfile.memReg[index] to inspect in src/Regfile.sv
#   - DMEMCHK : DataRam.memRam[word_index] / byte address to inspect in src/DataRam.sv
#   - x7      : not-taken fall-through counter
#   - x8      : taken-path counter
#   - x23     : data-memory base address used by load/store checks
# =============================================================================

start:
    # -------------------------------------------------------------------------
    # Basic ALU / immediate operations
    # -------------------------------------------------------------------------
    addi  x1,  x0, 15                    # PC=000 | HEX=0x00f00093 | GOLDEN: x1=0x0000000F | RFCHK: memReg[1]  | DMEMCHK: -
    addi  x2,  x0, 3                     # PC=004 | HEX=0x00300113 | GOLDEN: x2=0x00000003 | RFCHK: memReg[2]  | DMEMCHK: -
    addi  x3,  x0, -16                   # PC=008 | HEX=0xff000193 | GOLDEN: x3=0xFFFFFFF0 | RFCHK: memReg[3]  | DMEMCHK: -
    addi  x23, x0, 128                   # PC=012 | HEX=0x08000b93 | GOLDEN: x23=0x00000080 | RFCHK: memReg[23] | DMEMCHK: base addr=0x80
    addi  x24, x0, 144                   # PC=016 | HEX=0x09000c13 | GOLDEN: x24=0x00000090 | RFCHK: memReg[24] | DMEMCHK: -

    add   x4,  x1, x2                    # PC=020 | HEX=0x00208233 | GOLDEN: x4=0x00000012 | RFCHK: memReg[4]  | DMEMCHK: -
    sub   x5,  x1, x2                    # PC=024 | HEX=0x402082b3 | GOLDEN: x5=0x0000000C | RFCHK: memReg[5]  | DMEMCHK: -
    sll   x6,  x1, x2                    # PC=028 | HEX=0x00209333 | GOLDEN: x6=0x00000078 | RFCHK: memReg[6]  | DMEMCHK: -
    slt   x7,  x3, x1                    # PC=032 | HEX=0x0011a3b3 | GOLDEN: x7=0x00000001 | RFCHK: memReg[7]  | DMEMCHK: -
    sltu  x8,  x3, x1                    # PC=036 | HEX=0x0011b433 | GOLDEN: x8=0x00000000 | RFCHK: memReg[8]  | DMEMCHK: -
    xor   x9,  x1, x2                    # PC=040 | HEX=0x0020c4b3 | GOLDEN: x9=0x0000000C | RFCHK: memReg[9]  | DMEMCHK: -
    srl   x10, x1, x2                    # PC=044 | HEX=0x0020d533 | GOLDEN: x10=0x00000001 | RFCHK: memReg[10] | DMEMCHK: -
    sra   x11, x3, x2                    # PC=048 | HEX=0x4021d5b3 | GOLDEN: x11=0xFFFFFFFE | RFCHK: memReg[11] | DMEMCHK: -
    or    x12, x1, x2                    # PC=052 | HEX=0x0020e633 | GOLDEN: x12=0x0000000F | RFCHK: memReg[12] | DMEMCHK: -
    and   x13, x1, x2                    # PC=056 | HEX=0x0020f6b3 | GOLDEN: x13=0x00000003 | RFCHK: memReg[13] | DMEMCHK: -

    addi  x14, x1, 5                     # PC=060 | HEX=0x00508713 | GOLDEN: x14=0x00000014 | RFCHK: memReg[14] | DMEMCHK: -
    slti  x15, x3, 0                     # PC=064 | HEX=0x0001a793 | GOLDEN: x15=0x00000001 | RFCHK: memReg[15] | DMEMCHK: -
    sltiu x16, x3, 1                     # PC=068 | HEX=0x0011b813 | GOLDEN: x16=0x00000000 | RFCHK: memReg[16] | DMEMCHK: -
    xori  x17, x1, 3                     # PC=072 | HEX=0x0030c893 | GOLDEN: x17=0x0000000C | RFCHK: memReg[17] | DMEMCHK: -
    ori   x18, x1, 2                     # PC=076 | HEX=0x0020e913 | GOLDEN: x18=0x0000000F | RFCHK: memReg[18] | DMEMCHK: -
    andi  x19, x1, 7                     # PC=080 | HEX=0x0070f993 | GOLDEN: x19=0x00000007 | RFCHK: memReg[19] | DMEMCHK: -
    slli  x20, x2, 4                     # PC=084 | HEX=0x00411a13 | GOLDEN: x20=0x00000030 | RFCHK: memReg[20] | DMEMCHK: -
    srli  x21, x1, 1                     # PC=088 | HEX=0x0010da93 | GOLDEN: x21=0x00000007 | RFCHK: memReg[21] | DMEMCHK: -
    srai  x22, x3, 2                     # PC=092 | HEX=0x4021db13 | GOLDEN: x22=0xFFFFFFFC | RFCHK: memReg[22] | DMEMCHK: -
    lui   x25, 74565                     # PC=096 | HEX=0x12345cb7 | GOLDEN: x25=0x12345000 | RFCHK: memReg[25] | DMEMCHK: -
    auipc x26, 1                         # PC=100 | HEX=0x00001d17 | GOLDEN: x26=0x00001064 | RFCHK: memReg[26] | DMEMCHK: -

    # -------------------------------------------------------------------------
    # Load / store operations
    # -------------------------------------------------------------------------
    sw    x14, x23, 0                    # PC=104 | HEX=0x00eba023 | GOLDEN: MEM[0x80]=0x00000014 | RFCHK: memReg[14],memReg[23] | DMEMCHK: memRam[32] @ byte 0x80
    lw    x27, x23, 0                    # PC=108 | HEX=0x000bad83 | GOLDEN: x27=0x00000014 | RFCHK: memReg[27] | DMEMCHK: read memRam[32] @ byte 0x80
    add   x28, x27, x2                   # PC=112 | HEX=0x002d8e33 | GOLDEN: x28=0x00000017 | RFCHK: memReg[28] | DMEMCHK: -

    addi  x4,  x0, 128                   # PC=116 | HEX=0x08000213 | GOLDEN: x4=0x00000080 | RFCHK: memReg[4]  | DMEMCHK: -
    sb    x4,  x23, 4                    # PC=120 | HEX=0x004b8223 | GOLDEN: MEM8[0x84]=0x80 | RFCHK: memReg[4],memReg[23] | DMEMCHK: memRam[33][7:0] @ byte 0x84
    addi  x5,  x0, 127                   # PC=124 | HEX=0x07f00293 | GOLDEN: x5=0x0000007F | RFCHK: memReg[5]  | DMEMCHK: -
    sb    x5,  x23, 5                    # PC=128 | HEX=0x005b82a3 | GOLDEN: MEM8[0x85]=0x7F | RFCHK: memReg[5],memReg[23] | DMEMCHK: memRam[33][15:8] @ byte 0x85

    addi  x6,  x0, -14                   # PC=132 | HEX=0xff200313 | GOLDEN: x6=0xFFFFFFF2 | RFCHK: memReg[6]  | DMEMCHK: -
    slli  x6,  x6, 8                     # PC=136 | HEX=0x00831313 | GOLDEN: x6=0xFFFFF200 | RFCHK: memReg[6]  | DMEMCHK: -
    addi  x6,  x6, 52                    # PC=140 | HEX=0x03430313 | GOLDEN: x6=0xFFFFF234 | RFCHK: memReg[6]  | DMEMCHK: -
    sh    x6,  x23, 6                    # PC=144 | HEX=0x006b9323 | GOLDEN: MEM16[0x86]=0xF234, MEM32[0x84]=0xF2347F80 | RFCHK: memReg[6],memReg[23] | DMEMCHK: memRam[33][31:16] @ bytes 0x86-0x87

    lb    x29, x23, 4                    # PC=148 | HEX=0x004b8e83 | GOLDEN: x29=0xFFFFFF80 | RFCHK: memReg[29] | DMEMCHK: read byte 0x84 from memRam[33][7:0]
    lbu   x30, x23, 4                    # PC=152 | HEX=0x004bcf03 | GOLDEN: x30=0x00000080 | RFCHK: memReg[30] | DMEMCHK: read byte 0x84 from memRam[33][7:0]
    lh    x31, x23, 6                    # PC=156 | HEX=0x006b9f83 | GOLDEN: x31=0xFFFFF234 | RFCHK: memReg[31] | DMEMCHK: read half 0x86 from memRam[33][31:16]
    lhu   x4,  x23, 6                    # PC=160 | HEX=0x006bd203 | GOLDEN: x4=0x0000F234 | RFCHK: memReg[4]  | DMEMCHK: read half 0x86 from memRam[33][31:16]
    xor   x5,  x29, x30                  # PC=164 | HEX=0x01eec2b3 | GOLDEN: x5=0xFFFFFF00 | RFCHK: memReg[5]  | DMEMCHK: -
    add   x6,  x31, x4                   # PC=168 | HEX=0x004f8333 | GOLDEN: x6=0x0000E468 | RFCHK: memReg[6]  | DMEMCHK: -

    # -------------------------------------------------------------------------
    # Branch operations
    #   - x7 : not-taken fall-through counter
    #   - x8 : taken-path counter
    # -------------------------------------------------------------------------
    addi  x7,  x0, 0                     # PC=172 | HEX=0x00000393 | GOLDEN: x7=0x00000000 | RFCHK: memReg[7]  | DMEMCHK: -
    addi  x8,  x0, 0                     # PC=176 | HEX=0x00000413 | GOLDEN: x8=0x00000000 | RFCHK: memReg[8]  | DMEMCHK: -

    beq   x1,  x2, beq_nt_skip           # PC=180 | HEX=0x00208463 | GOLDEN: NOT TAKEN, next PC=184, x7 stays 0x00000000 | RFCHK: memReg[7]  | DMEMCHK: -
    addi  x7,  x7, 1                     # PC=184 | HEX=0x00138393 | GOLDEN: x7=0x00000001 | RFCHK: memReg[7]  | DMEMCHK: -
beq_nt_skip:
    beq   x1,  x1, beq_t_target          # PC=188 | HEX=0x00108463 | GOLDEN: TAKEN, skip PC=192, x8 stays 0x00000000 | RFCHK: memReg[8]  | DMEMCHK: -
    addi  x8,  x8, 99                    # PC=192 | HEX=0x06340413 | GOLDEN: SKIPPED, x8 remains 0x00000000 | RFCHK: memReg[8]  | DMEMCHK: -
beq_t_target:
    addi  x8,  x8, 1                     # PC=196 | HEX=0x00140413 | GOLDEN: x8=0x00000001 | RFCHK: memReg[8]  | DMEMCHK: -

    bne   x1,  x1, bne_nt_skip           # PC=200 | HEX=0x00109463 | GOLDEN: NOT TAKEN, next PC=204, x7 stays 0x00000001 | RFCHK: memReg[7]  | DMEMCHK: -
    addi  x7,  x7, 1                     # PC=204 | HEX=0x00138393 | GOLDEN: x7=0x00000002 | RFCHK: memReg[7]  | DMEMCHK: -
bne_nt_skip:
    bne   x1,  x2, bne_t_target          # PC=208 | HEX=0x00209463 | GOLDEN: TAKEN, skip PC=212, x8 stays 0x00000001 | RFCHK: memReg[8]  | DMEMCHK: -
    addi  x8,  x8, 99                    # PC=212 | HEX=0x06340413 | GOLDEN: SKIPPED, x8 remains 0x00000001 | RFCHK: memReg[8]  | DMEMCHK: -
bne_t_target:
    addi  x8,  x8, 1                     # PC=216 | HEX=0x00140413 | GOLDEN: x8=0x00000002 | RFCHK: memReg[8]  | DMEMCHK: -

    blt   x1,  x2, blt_nt_skip           # PC=220 | HEX=0x0020c463 | GOLDEN: NOT TAKEN, next PC=224, x7 stays 0x00000002 | RFCHK: memReg[7]  | DMEMCHK: -
    addi  x7,  x7, 1                     # PC=224 | HEX=0x00138393 | GOLDEN: x7=0x00000003 | RFCHK: memReg[7]  | DMEMCHK: -
blt_nt_skip:
    blt   x3,  x1, blt_t_target          # PC=228 | HEX=0x0011c463 | GOLDEN: TAKEN, skip PC=232, x8 stays 0x00000002 | RFCHK: memReg[8]  | DMEMCHK: -
    addi  x8,  x8, 99                    # PC=232 | HEX=0x06340413 | GOLDEN: SKIPPED, x8 remains 0x00000002 | RFCHK: memReg[8]  | DMEMCHK: -
blt_t_target:
    addi  x8,  x8, 1                     # PC=236 | HEX=0x00140413 | GOLDEN: x8=0x00000003 | RFCHK: memReg[8]  | DMEMCHK: -

    bge   x2,  x1, bge_nt_skip           # PC=240 | HEX=0x00115463 | GOLDEN: NOT TAKEN, next PC=244, x7 stays 0x00000003 | RFCHK: memReg[7]  | DMEMCHK: -
    addi  x7,  x7, 1                     # PC=244 | HEX=0x00138393 | GOLDEN: x7=0x00000004 | RFCHK: memReg[7]  | DMEMCHK: -
bge_nt_skip:
    bge   x1,  x2, bge_t_target          # PC=248 | HEX=0x0020d463 | GOLDEN: TAKEN, skip PC=252, x8 stays 0x00000003 | RFCHK: memReg[8]  | DMEMCHK: -
    addi  x8,  x8, 99                    # PC=252 | HEX=0x06340413 | GOLDEN: SKIPPED, x8 remains 0x00000003 | RFCHK: memReg[8]  | DMEMCHK: -
bge_t_target:
    addi  x8,  x8, 1                     # PC=256 | HEX=0x00140413 | GOLDEN: x8=0x00000004 | RFCHK: memReg[8]  | DMEMCHK: -

    bltu  x1,  x2, bltu_nt_skip          # PC=260 | HEX=0x0020e463 | GOLDEN: NOT TAKEN, next PC=264, x7 stays 0x00000004 | RFCHK: memReg[7]  | DMEMCHK: -
    addi  x7,  x7, 1                     # PC=264 | HEX=0x00138393 | GOLDEN: x7=0x00000005 | RFCHK: memReg[7]  | DMEMCHK: -
bltu_nt_skip:
    bltu  x2,  x1, bltu_t_target         # PC=268 | HEX=0x00116463 | GOLDEN: TAKEN, skip PC=272, x8 stays 0x00000004 | RFCHK: memReg[8]  | DMEMCHK: -
    addi  x8,  x8, 99                    # PC=272 | HEX=0x06340413 | GOLDEN: SKIPPED, x8 remains 0x00000004 | RFCHK: memReg[8]  | DMEMCHK: -
bltu_t_target:
    addi  x8,  x8, 1                     # PC=276 | HEX=0x00140413 | GOLDEN: x8=0x00000005 | RFCHK: memReg[8]  | DMEMCHK: -

    bgeu  x2,  x1, bgeu_nt_skip          # PC=280 | HEX=0x00117463 | GOLDEN: NOT TAKEN, next PC=284, x7 stays 0x00000005 | RFCHK: memReg[7]  | DMEMCHK: -
    addi  x7,  x7, 1                     # PC=284 | HEX=0x00138393 | GOLDEN: x7=0x00000006 | RFCHK: memReg[7]  | DMEMCHK: -
bgeu_nt_skip:
    bgeu  x1,  x2, bgeu_t_target         # PC=288 | HEX=0x0020f463 | GOLDEN: TAKEN, skip PC=292, x8 stays 0x00000005 | RFCHK: memReg[8]  | DMEMCHK: -
    addi  x8,  x8, 99                    # PC=292 | HEX=0x06340413 | GOLDEN: SKIPPED, x8 remains 0x00000005 | RFCHK: memReg[8]  | DMEMCHK: -
bgeu_t_target:
    addi  x8,  x8, 1                     # PC=296 | HEX=0x00140413 | GOLDEN: x8=0x00000006 | RFCHK: memReg[8]  | DMEMCHK: -

    # -------------------------------------------------------------------------
    # Loop / jump operations
    # -------------------------------------------------------------------------
    addi  x9,  x0, 4                     # PC=300 | HEX=0x00400493 | GOLDEN: x9=0x00000004 | RFCHK: memReg[9]  | DMEMCHK: -
    addi  x10, x0, 0                     # PC=304 | HEX=0x00000513 | GOLDEN: x10=0x00000000 | RFCHK: memReg[10] | DMEMCHK: -
loop_body:
    addi  x9,  x9, -1                    # PC=308 | HEX=0xfff48493 | GOLDEN: x9=0x00000003->0x00000002->0x00000001->0x00000000 | RFCHK: memReg[9]  | DMEMCHK: -
    add   x10, x10, x9                   # PC=312 | HEX=0x00950533 | GOLDEN: x10=0x00000003->0x00000005->0x00000006->0x00000006 | RFCHK: memReg[10] | DMEMCHK: -
    bne   x9,  x0, loop_body             # PC=316 | HEX=0xfe049ce3 | GOLDEN: TAKEN x3, final NOT TAKEN when x9=0x00000000 | RFCHK: memReg[9],memReg[10] | DMEMCHK: -

    jal   x11, jal_target                # PC=320 | HEX=0x008005ef | GOLDEN: x11=0x00000144, jump to PC=328 | RFCHK: memReg[11] | DMEMCHK: -
    addi  x12, x0, 111                   # PC=324 | HEX=0x06f00613 | GOLDEN: SKIPPED, x12 remains 0x0000000F | RFCHK: memReg[12] | DMEMCHK: -
jal_target:
    auipc x12, 0                         # PC=328 | HEX=0x00000617 | GOLDEN: x12=0x00000148 | RFCHK: memReg[12] | DMEMCHK: -
    addi  x12, x12, 16                   # PC=332 | HEX=0x01060613 | GOLDEN: x12=0x00000158 | RFCHK: memReg[12] | DMEMCHK: -
    jalr  x13, x12, 0                    # PC=336 | HEX=0x000606e7 | GOLDEN: x13=0x00000154, jump to PC=344 | RFCHK: memReg[13] | DMEMCHK: -
    addi  x14, x0, 222                   # PC=340 | HEX=0x0de00713 | GOLDEN: SKIPPED, x14 remains 0x00000014 | RFCHK: memReg[14] | DMEMCHK: -

after_jalr:
    addi  x15, x0, 55                    # PC=344 | HEX=0x03700793 | GOLDEN: x15=0x00000037 | RFCHK: memReg[15] | DMEMCHK: -
    fence                                # PC=348 | HEX=0x0000000f | GOLDEN: no architectural register change | RFCHK: - | DMEMCHK: -
    add   x16, x25, x1                   # PC=352 | HEX=0x001c8833 | GOLDEN: x16=0x1234500F | RFCHK: memReg[16] | DMEMCHK: -
    add   x17, x26, x2                   # PC=356 | HEX=0x002d08b3 | GOLDEN: x17=0x00001067 | RFCHK: memReg[17] | DMEMCHK: -

done:
    jal   x0,  done                      # PC=360 | HEX=0x0000006f | GOLDEN: self-loop, PC stays 360 | RFCHK: memReg[0]=0x00000000 | DMEMCHK: -
