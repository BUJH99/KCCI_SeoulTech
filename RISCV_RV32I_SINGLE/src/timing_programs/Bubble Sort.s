# =============================================================================
# RV32I bubble-sort timing program
#   - Sort four 32-bit words in descending order at byte address 0x100.
#   - ARRAY    : DataRam.memRam[64:67] / byte addresses 0x100-0x10f
#   - DONE flag: DataRam.memRam[68]     / byte address 0x110
#   - s0 / x8  : array base address
#   - s1 / x9  : element count
#   - s2 / x18 : done-flag address
# =============================================================================

start:
    # -------------------------------------------------------------------------
    # Program setup / seed unsorted data
    # -------------------------------------------------------------------------
    addi  s0, x0, 0x100                  # PC=000 | HEX=0x10000413 | GOLDEN: s0=0x00000100 | RFCHK: memReg[8]  | DMEMCHK: array base=0x100
    addi  s1, x0, 4                      # PC=004 | HEX=0x00400493 | GOLDEN: s1=0x00000004 | RFCHK: memReg[9]  | DMEMCHK: element count
    addi  s2, x0, 0x110                  # PC=008 | HEX=0x11000913 | GOLDEN: s2=0x00000110 | RFCHK: memReg[18] | DMEMCHK: done-flag addr=0x110

    addi  t0, x0, 3                      # PC=012 | HEX=0x00300293 | GOLDEN: t0=0x00000003 | RFCHK: memReg[5]  | DMEMCHK: seed array[0]
    sw    t0, 0(s0)                      # PC=016 | HEX=0x00542023 | GOLDEN: MEM[0x100]=0x00000003 | RFCHK: memReg[5],memReg[8]  | DMEMCHK: memRam[64] @ byte 0x100
    addi  t0, x0, 1                      # PC=020 | HEX=0x00100293 | GOLDEN: t0=0x00000001 | RFCHK: memReg[5]  | DMEMCHK: seed array[1]
    sw    t0, 4(s0)                      # PC=024 | HEX=0x00542223 | GOLDEN: MEM[0x104]=0x00000001 | RFCHK: memReg[5],memReg[8]  | DMEMCHK: memRam[65] @ byte 0x104
    addi  t0, x0, 4                      # PC=028 | HEX=0x00400293 | GOLDEN: t0=0x00000004 | RFCHK: memReg[5]  | DMEMCHK: seed array[2]
    sw    t0, 8(s0)                      # PC=032 | HEX=0x00542423 | GOLDEN: MEM[0x108]=0x00000004 | RFCHK: memReg[5],memReg[8]  | DMEMCHK: memRam[66] @ byte 0x108
    addi  t0, x0, 2                      # PC=036 | HEX=0x00200293 | GOLDEN: t0=0x00000002 | RFCHK: memReg[5]  | DMEMCHK: seed array[3]
    sw    t0, 12(s0)                     # PC=040 | HEX=0x00542623 | GOLDEN: MEM[0x10c]=0x00000002 | RFCHK: memReg[5],memReg[8]  | DMEMCHK: memRam[67] @ byte 0x10c

    sw    x0, 0(s2)                      # PC=044 | HEX=0x00092023 | GOLDEN: MEM[0x110]=0x00000000 | RFCHK: memReg[18] | DMEMCHK: clear memRam[68] @ byte 0x110
    addi  t0, x0, 0                      # PC=048 | HEX=0x00000293 | GOLDEN: t0=0x00000000 | RFCHK: memReg[5]  | DMEMCHK: outer-loop index reset

outer_loop:
    # -------------------------------------------------------------------------
    # Bubble-sort outer / inner loops
    # -------------------------------------------------------------------------
    addi  t2, s1, -1                     # PC=052 | HEX=0xfff48393 | GOLDEN: t2=0x00000003 | RFCHK: memReg[7]  | DMEMCHK: upper bound = count-1
    bge   t0, t2, sort_done              # PC=056 | HEX=0x0272de63 | GOLDEN: branch to sort_done when t0 reaches 3 | RFCHK: memReg[5],memReg[7]  | DMEMCHK: -
    addi  t1, x0, 0                      # PC=060 | HEX=0x00000313 | GOLDEN: t1=0x00000000 | RFCHK: memReg[6]  | DMEMCHK: inner-loop index reset

inner_loop:
    sub   t3, t2, t0                     # PC=064 | HEX=0x40538e33 | GOLDEN: t3=remaining comparisons in this pass | RFCHK: memReg[28] | DMEMCHK: -
    bge   t1, t3, next_outer             # PC=068 | HEX=0x03c35463 | GOLDEN: branch when current pass is complete | RFCHK: memReg[6],memReg[28] | DMEMCHK: -
    slli  t4, t1, 2                      # PC=072 | HEX=0x00231e93 | GOLDEN: t4=t1*4 byte offset | RFCHK: memReg[29] | DMEMCHK: -
    add   t4, s0, t4                     # PC=076 | HEX=0x01d40eb3 | GOLDEN: t4=&array[t1] | RFCHK: memReg[29] | DMEMCHK: base 0x100 + offset
    lw    t5, 0(t4)                      # PC=080 | HEX=0x000eaf03 | GOLDEN: t5=array[t1] | RFCHK: memReg[30] | DMEMCHK: read current word
    lw    t6, 4(t4)                      # PC=084 | HEX=0x004eaf83 | GOLDEN: t6=array[t1+1] | RFCHK: memReg[31] | DMEMCHK: read next word
    bge   t5, t6, no_swap                # PC=088 | HEX=0x01ff5663 | GOLDEN: keep order when left >= right | RFCHK: memReg[30],memReg[31] | DMEMCHK: -
    sw    t6, 0(t4)                      # PC=092 | HEX=0x01fea023 | GOLDEN: array[t1]=previous array[t1+1] | RFCHK: memReg[29],memReg[31] | DMEMCHK: swap left word
    sw    t5, 4(t4)                      # PC=096 | HEX=0x01eea223 | GOLDEN: array[t1+1]=previous array[t1] | RFCHK: memReg[29],memReg[30] | DMEMCHK: swap right word

no_swap:
    addi  t1, t1, 1                      # PC=100 | HEX=0x00130313 | GOLDEN: t1=t1+1 | RFCHK: memReg[6]  | DMEMCHK: advance inner-loop index
    jal   x0, inner_loop                 # PC=104 | HEX=0xfddff06f | GOLDEN: jump back to inner_loop | RFCHK: x0 discard | DMEMCHK: -

next_outer:
    addi  t0, t0, 1                      # PC=108 | HEX=0x00128293 | GOLDEN: t0=t0+1 | RFCHK: memReg[5]  | DMEMCHK: advance outer-loop index
    jal   x0, outer_loop                 # PC=112 | HEX=0xfc5ff06f | GOLDEN: jump back to outer_loop | RFCHK: x0 discard | DMEMCHK: -

sort_done:
    # -------------------------------------------------------------------------
    # Completion flag / terminal loop
    # -------------------------------------------------------------------------
    addi  t0, x0, 1                      # PC=116 | HEX=0x00100293 | GOLDEN: t0=0x00000001 | RFCHK: memReg[5]  | DMEMCHK: done-flag value
    sw    t0, 0(s2)                      # PC=120 | HEX=0x00592023 | GOLDEN: MEM[0x110]=0x00000001, array sorted as 4,3,2,1 | RFCHK: memReg[5],memReg[18] | DMEMCHK: memRam[68] @ byte 0x110

end_loop:
    jal   x0, end_loop                   # PC=124 | HEX=0x0000006f | GOLDEN: self loop at PC=124 | RFCHK: x0 discard | DMEMCHK: -
