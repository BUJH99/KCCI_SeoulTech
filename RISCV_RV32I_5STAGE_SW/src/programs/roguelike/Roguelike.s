	.file	"roguelike_port.c"
	.option nopic
	.attribute arch, "rv32i2p1"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.section	.text.rng_next,"ax",@progbits
	.align	2
	.type	rng_next, @function
rng_next:
	lui	a3,%hi(gRngState)
	lw	a5,%lo(gRngState)(a3)
	bne	a5,zero,.L2
	li	a5,324509696
	addi	a5,a5,-1057
.L2:
	slli	a4,a5,13
	xor	a4,a4,a5
	srli	a5,a4,17
	xor	a5,a5,a4
	slli	a0,a5,5
	xor	a0,a0,a5
	sw	a0,%lo(gRngState)(a3)
	ret
	.size	rng_next, .-rng_next
	.section	.text.rng_range,"ax",@progbits
	.align	2
	.type	rng_range, @function
rng_range:
	beq	a0,zero,.L10
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	a0,12(sp)
	call	rng_next
	lw	a1,12(sp)
	call	__umodsi3
	lw	ra,28(sp)
	addi	sp,sp,32
	jr	ra
.L10:
	ret
	.size	rng_range, .-rng_range
	.section	.text.uart_putc,"ax",@progbits
	.align	2
	.type	uart_putc, @function
uart_putc:
	li	a4,1073741824
	addi	a4,a4,4
.L14:
	lw	a5,0(a4)
	andi	a5,a5,2
	beq	a5,zero,.L14
	li	a5,1073741824
	sw	a0,8(a5)
	ret
	.size	uart_putc, .-uart_putc
	.section	.text.emit_str,"ax",@progbits
	.align	2
	.type	emit_str, @function
emit_str:
	addi	sp,sp,-16
	sw	s0,8(sp)
	sw	ra,12(sp)
	mv	s0,a0
.L18:
	lbu	a0,0(s0)
	bne	a0,zero,.L19
	lw	ra,12(sp)
	lw	s0,8(sp)
	addi	sp,sp,16
	jr	ra
.L19:
	call	uart_putc
	addi	s0,s0,1
	j	.L18
	.size	emit_str, .-emit_str
	.section	.text.emit_crlf,"ax",@progbits
	.align	2
	.type	emit_crlf, @function
emit_crlf:
	addi	sp,sp,-16
	li	a0,13
	sw	ra,12(sp)
	call	uart_putc
	lw	ra,12(sp)
	li	a0,10
	addi	sp,sp,16
	tail	uart_putc
	.size	emit_crlf, .-emit_crlf
	.section	.text.term_home,"ax",@progbits
	.align	2
	.type	term_home, @function
term_home:
	addi	sp,sp,-16
	li	a0,27
	sw	ra,12(sp)
	call	uart_putc
	li	a0,91
	call	uart_putc
	lw	ra,12(sp)
	li	a0,72
	addi	sp,sp,16
	tail	uart_putc
	.size	term_home, .-term_home
	.section	.text.fnd_write_gold,"ax",@progbits
	.align	2
	.type	fnd_write_gold, @function
fnd_write_gold:
	lui	a5,%hi(gGoldTotal)
	lw	a5,%lo(gGoldTotal)(a5)
	li	a4,8192
	addi	a4,a4,1807
	bleu	a5,a4,.L26
	mv	a5,a4
.L26:
	li	a4,0
	li	a3,999
.L27:
	bgtu	a5,a3,.L28
	li	a2,0
	li	a3,99
.L29:
	bgtu	a5,a3,.L30
	li	a3,0
	li	a1,9
.L31:
	bgtu	a5,a1,.L32
	slli	a4,a4,12
	slli	a2,a2,8
	or	a4,a4,a2
	li	a1,1073750016
	li	a0,1
	or	a4,a4,a5
	slli	a3,a3,4
	sw	a0,12(a1)
	or	a4,a4,a3
	sw	a4,0(a1)
	ret
.L28:
	addi	a5,a5,-1000
	addi	a4,a4,1
	j	.L27
.L30:
	addi	a5,a5,-100
	addi	a2,a2,1
	j	.L29
.L32:
	addi	a5,a5,-10
	addi	a3,a3,1
	j	.L31
	.size	fnd_write_gold, .-fnd_write_gold
	.section	.text.coord_in_bounds,"ax",@progbits
	.align	2
	.type	coord_in_bounds, @function
coord_in_bounds:
	or	a5,a0,a1
	blt	a5,zero,.L35
	sltiu	a1,a1,14
	sltiu	a0,a0,30
	seqz	a1,a1
	seqz	a0,a0
	or	a0,a1,a0
	xori	a0,a0,1
	ret
.L35:
	li	a0,0
	ret
	.size	coord_in_bounds, .-coord_in_bounds
	.section	.text.enemy_at,"ax",@progbits
	.align	2
	.type	enemy_at, @function
enemy_at:
	lui	a5,%hi(gEnemyCount)
	lbu	a3,%lo(gEnemyCount)(a5)
	lui	a5,%hi(gEnemies)
	addi	a5,a5,%lo(gEnemies)
	li	a4,0
.L37:
	bgtu	a3,a4,.L40
	li	a4,-1
.L36:
	mv	a0,a4
	ret
.L40:
	lbu	a2,0(a5)
	bne	a2,a0,.L38
	lbu	a2,1(a5)
	beq	a2,a1,.L36
.L38:
	addi	a4,a4,1
	addi	a5,a5,3
	j	.L37
	.size	enemy_at, .-enemy_at
	.section	.text.gold_at,"ax",@progbits
	.align	2
	.type	gold_at, @function
gold_at:
	lui	a5,%hi(gGoldCount)
	lbu	a3,%lo(gGoldCount)(a5)
	lui	a5,%hi(gGold)
	addi	a5,a5,%lo(gGold)
	li	a4,0
.L42:
	bgtu	a3,a4,.L45
	li	a4,-1
.L41:
	mv	a0,a4
	ret
.L45:
	lbu	a2,0(a5)
	bne	a2,a0,.L43
	lbu	a2,1(a5)
	beq	a2,a1,.L41
.L43:
	addi	a4,a4,1
	addi	a5,a5,3
	j	.L42
	.size	gold_at, .-gold_at
	.section	.text.emit_border,"ax",@progbits
	.align	2
	.type	emit_border, @function
emit_border:
	addi	sp,sp,-16
	li	a0,43
	sw	s0,8(sp)
	sw	ra,12(sp)
	li	s0,30
	call	uart_putc
.L47:
	li	a0,45
	addi	s0,s0,-1
	call	uart_putc
	bne	s0,zero,.L47
	li	a0,43
	call	uart_putc
	lw	s0,8(sp)
	lw	ra,12(sp)
	addi	sp,sp,16
	tail	emit_crlf
	.size	emit_border, .-emit_border
	.section	.text.emit_dec_u32,"ax",@progbits
	.align	2
	.type	emit_dec_u32, @function
emit_dec_u32:
	beq	a0,zero,.L58
	addi	sp,sp,-48
	sw	s0,40(sp)
	sw	s1,36(sp)
	sw	s2,32(sp)
	sw	s3,28(sp)
	sw	s4,24(sp)
	sw	ra,44(sp)
	sw	s5,20(sp)
	mv	s0,a0
	li	s1,0
	addi	s2,sp,4
	li	s3,10
	li	s4,9
.L51:
	li	a1,10
	mv	a0,s0
	call	__umodsi3
	add	s5,s2,s1
	addi	a0,a0,48
	sb	a0,0(s5)
	addi	s1,s1,1
	bleu	s0,s4,.L53
	mv	a0,s0
	li	a1,10
	call	__udivsi3
	mv	s0,a0
	bne	s1,s3,.L51
.L53:
	addi	s1,s1,-1
	add	a5,s2,s1
	lbu	a0,0(a5)
	call	uart_putc
	bne	s1,zero,.L53
	lw	ra,44(sp)
	lw	s0,40(sp)
	lw	s1,36(sp)
	lw	s2,32(sp)
	lw	s3,28(sp)
	lw	s4,24(sp)
	lw	s5,20(sp)
	addi	sp,sp,48
	jr	ra
.L58:
	li	a0,48
	tail	uart_putc
	.size	emit_dec_u32, .-emit_dec_u32
	.section	.text.spawn_blocked,"ax",@progbits
	.align	2
	.type	spawn_blocked, @function
spawn_blocked:
	lui	a5,%hi(gPlayerX)
	lbu	a5,%lo(gPlayerX)(a5)
	bne	a5,a0,.L63
	lui	a5,%hi(gPlayerY)
	lbu	a4,%lo(gPlayerY)(a5)
	li	a5,1
	beq	a4,a1,.L70
.L63:
	lui	a5,%hi(gStairsX)
	lbu	a5,%lo(gStairsX)(a5)
	bne	a5,a0,.L65
	lui	a5,%hi(gStairsY)
	lbu	a4,%lo(gStairsY)(a5)
	li	a5,1
	beq	a4,a1,.L70
.L65:
	addi	sp,sp,-32
	sw	s0,24(sp)
	sw	ra,28(sp)
	mv	s0,a0
	sw	a1,12(sp)
	call	enemy_at
	li	a4,-1
	li	a5,1
	bne	a0,a4,.L62
	lw	a1,12(sp)
	mv	a0,s0
	call	gold_at
	addi	a5,a0,1
	snez	a5,a5
.L62:
	lw	ra,28(sp)
	lw	s0,24(sp)
	mv	a0,a5
	addi	sp,sp,32
	jr	ra
.L70:
	mv	a0,a5
	ret
	.size	spawn_blocked, .-spawn_blocked
	.section	.text.enemy_try_step,"ax",@progbits
	.align	2
	.type	enemy_try_step, @function
enemy_try_step:
	addi	sp,sp,-48
	sw	ra,44(sp)
	sw	s0,40(sp)
	sw	s1,36(sp)
	sw	s2,32(sp)
	sw	s3,28(sp)
	sw	s4,24(sp)
	sw	s5,20(sp)
	or	a5,a1,a2
	beq	a5,zero,.L78
	slli	s5,a0,1
	lui	s2,%hi(gEnemies)
	add	a5,s5,a0
	addi	s2,s2,%lo(gEnemies)
	add	a5,s2,a5
	lbu	s3,0(a5)
	lbu	s0,1(a5)
	mv	s4,a0
	add	s3,s3,a1
	add	s0,s0,a2
	mv	a1,s0
	mv	a0,s3
	sw	a3,12(sp)
	call	coord_in_bounds
	mv	s1,a0
	beq	a0,zero,.L72
	lui	a5,%hi(gPlayerX)
	lbu	a5,%lo(gPlayerX)(a5)
	lw	a3,12(sp)
	bne	a5,s3,.L74
	lui	a5,%hi(gPlayerY)
	lbu	a5,%lo(gPlayerY)(a5)
	bne	a5,s0,.L74
	lw	a5,0(a3)
	addi	a5,a5,1
	sw	a5,0(a3)
.L72:
	lw	ra,44(sp)
	lw	s0,40(sp)
	lw	s2,32(sp)
	lw	s3,28(sp)
	lw	s4,24(sp)
	lw	s5,20(sp)
	mv	a0,s1
	lw	s1,36(sp)
	addi	sp,sp,48
	jr	ra
.L74:
	slli	a4,s0,4
	lui	a5,%hi(gMap)
	sub	a4,a4,s0
	slli	a4,a4,1
	addi	a5,a5,%lo(gMap)
	add	a5,a5,a4
	add	a5,a5,s3
	lbu	a5,0(a5)
	beq	a5,zero,.L78
	mv	a1,s0
	mv	a0,s3
	call	enemy_at
	li	a5,-1
	bne	a0,a5,.L78
	add	s5,s5,s4
	add	s2,s2,s5
	sb	s3,0(s2)
	sb	s0,1(s2)
	j	.L72
.L78:
	li	s1,0
	j	.L72
	.size	enemy_try_step, .-enemy_try_step
	.section	.text.attempt_move_player,"ax",@progbits
	.align	2
	.type	attempt_move_player, @function
attempt_move_player:
	addi	sp,sp,-32
	sw	s2,16(sp)
	sw	s6,0(sp)
	lui	s2,%hi(gPlayerX)
	lui	s6,%hi(gPlayerY)
	sw	s0,24(sp)
	sw	s1,20(sp)
	lbu	s0,%lo(gPlayerY)(s6)
	lbu	s1,%lo(gPlayerX)(s2)
	sw	ra,28(sp)
	add	s0,s0,a1
	add	s1,s1,a0
	mv	a1,s0
	mv	a0,s1
	sw	s3,12(sp)
	sw	s4,8(sp)
	sw	s5,4(sp)
	call	coord_in_bounds
	bne	a0,zero,.L84
.L86:
	lui	a5,%hi(gMessageId)
	li	a4,7
	sb	a4,%lo(gMessageId)(a5)
	lui	a5,%hi(gMessageValue)
	sw	zero,%lo(gMessageValue)(a5)
	li	s3,0
.L83:
	lw	ra,28(sp)
	lw	s0,24(sp)
	lw	s1,20(sp)
	lw	s2,16(sp)
	lw	s4,8(sp)
	lw	s5,4(sp)
	lw	s6,0(sp)
	mv	a0,s3
	lw	s3,12(sp)
	addi	sp,sp,32
	jr	ra
.L84:
	slli	a5,s0,4
	lui	s5,%hi(gMap)
	sub	a5,a5,s0
	addi	s5,s5,%lo(gMap)
	slli	a5,a5,1
	add	a5,s5,a5
	add	a5,a5,s1
	lbu	a5,0(a5)
	beq	a5,zero,.L86
	mv	s3,a0
	mv	a1,s0
	mv	a0,s1
	call	enemy_at
	li	a5,-1
	mv	s4,a0
	beq	a0,a5,.L87
	lui	s0,%hi(gEnemies)
	slli	a5,a0,1
	add	a5,a5,a0
	addi	s0,s0,%lo(gEnemies)
	add	s0,s0,a5
	lbu	a5,2(s0)
	li	a4,1
	bgtu	a5,a4,.L88
	lui	s2,%hi(gEnemyCount)
	lbu	s1,%lo(gEnemyCount)(s2)
.L89:
	addi	s4,s4,1
	bltu	s4,s1,.L91
	beq	s1,zero,.L92
	addi	s1,s1,-1
	sb	s1,%lo(gEnemyCount)(s2)
.L92:
	lui	a5,%hi(gMessageId)
	li	a4,3
	sb	a4,%lo(gMessageId)(a5)
	lui	a5,%hi(gMessageValue)
	sw	zero,%lo(gMessageValue)(a5)
	j	.L83
.L88:
	lui	a4,%hi(gMessageId)
	addi	a5,a5,-1
	li	a3,2
	andi	a5,a5,0xff
	sb	a3,%lo(gMessageId)(a4)
	lui	a4,%hi(gMessageValue)
	sb	a5,2(s0)
	sw	a5,%lo(gMessageValue)(a4)
	j	.L83
.L91:
	addi	s0,s0,3
	li	a2,3
	mv	a1,s0
	addi	a0,s0,-3
	call	memcpy
	j	.L89
.L87:
	sb	s1,%lo(gPlayerX)(s2)
	sb	s0,%lo(gPlayerY)(s6)
	andi	s1,s1,255
	andi	s0,s0,255
	mv	a1,s0
	mv	a0,s1
	call	gold_at
	mv	s2,a0
	beq	a0,s4,.L93
	lui	s0,%hi(gGold)
	slli	a4,a0,1
	addi	s0,s0,%lo(gGold)
	add	a5,a4,a0
	add	a5,s0,a5
	lui	a2,%hi(gGoldTotal)
	lbu	s4,2(a5)
	lw	a5,%lo(gGoldTotal)(a2)
	li	a3,8192
	addi	a3,a3,1807
	add	a5,a5,s4
	bleu	a5,a3,.L94
	mv	a5,a3
.L94:
	lui	s5,%hi(gGoldCount)
	lbu	s1,%lo(gGoldCount)(s5)
	add	a4,a4,s2
	sw	a5,%lo(gGoldTotal)(a2)
	add	s0,s0,a4
.L95:
	addi	s2,s2,1
	bltu	s2,s1,.L96
	beq	s1,zero,.L97
	addi	s1,s1,-1
	sb	s1,%lo(gGoldCount)(s5)
.L97:
	call	fnd_write_gold
	lui	a5,%hi(gMessageId)
	li	a4,1
	sb	a4,%lo(gMessageId)(a5)
	lui	a5,%hi(gMessageValue)
	sw	s4,%lo(gMessageValue)(a5)
	j	.L83
.L96:
	addi	s0,s0,3
	li	a2,3
	mv	a1,s0
	addi	a0,s0,-3
	call	memcpy
	j	.L95
.L93:
	slli	a5,s0,4
	sub	a5,a5,s0
	slli	a5,a5,1
	add	s5,s5,a5
	add	s5,s5,s1
	lbu	a4,0(s5)
	li	a5,2
	bne	a4,a5,.L83
	lui	a5,%hi(gFloor)
	lbu	a4,%lo(gFloor)(a5)
	li	a3,5
	lui	a5,%hi(gMessageId)
	sb	a3,%lo(gMessageId)(a5)
	lui	a5,%hi(gMessageValue)
	sw	a4,%lo(gMessageValue)(a5)
	j	.L83
	.size	attempt_move_player, .-attempt_move_player
	.section	.text.build_floor,"ax",@progbits
	.align	2
	.type	build_floor, @function
build_floor:
	addi	sp,sp,-96
	sw	s4,72(sp)
	lui	s4,%hi(gMap)
	sw	ra,92(sp)
	sw	s0,88(sp)
	sw	s1,84(sp)
	sw	s2,80(sp)
	sw	s3,76(sp)
	sw	s5,68(sp)
	sw	s6,64(sp)
	sw	s7,60(sp)
	sw	s8,56(sp)
	sw	s9,52(sp)
	sw	s10,48(sp)
	sw	s11,44(sp)
	li	a5,0
	addi	s4,s4,%lo(gMap)
	li	a4,420
.L110:
	add	a3,a5,s4
	sb	zero,0(a3)
	addi	a5,a5,1
	bne	a5,a4,.L110
	call	rng_next
	li	a1,6
	call	__umodsi3
	lui	s10,%hi(gRooms)
	mv	s5,a0
	li	s9,0
	li	s1,0
	li	s3,9
	li	s2,6
	addi	s10,s10,%lo(gRooms)
	li	s11,1
.L115:
	beq	s5,s1,.L111
	call	rng_next
	li	a1,5
	call	__umodsi3
	addi	s6,a0,4
	call	rng_next
	li	a1,3
	call	__umodsi3
	addi	s8,a0,3
	sub	a0,s3,s6
	call	rng_range
	mv	s7,a0
	li	a1,3
	mv	a0,s1
	call	__umodsi3
	slli	a5,a0,2
	add	s0,a5,a0
	slli	s0,s0,1
	sub	a0,s2,s8
	call	rng_range
	addi	s0,s0,1
	add	s0,s0,s7
	li	a1,3
	mv	s7,a0
	mv	a0,s1
	call	__udivsi3
	neg	a5,a0
	andi	a5,a5,7
	addi	a5,a5,1
	add	a5,a5,s7
	slli	a4,s9,2
	add	a4,s10,a4
	andi	a5,a5,0xff
	andi	s0,s0,0xff
	sb	a5,1(a4)
	sb	s0,0(a4)
	sb	s6,2(a4)
	sb	s8,3(a4)
	slli	a4,a5,4
	sub	a5,a4,a5
	slli	a5,a5,1
	add	a5,a5,s0
	li	a3,0
.L112:
	li	a4,0
	add	a2,s4,a5
.L113:
	add	a1,a2,a4
	sb	s11,0(a1)
	addi	a4,a4,1
	bgtu	s6,a4,.L113
	addi	a3,a3,1
	addi	a5,a5,30
	bgtu	s8,a3,.L112
	addi	s9,s9,1
.L111:
	addi	s1,s1,1
	bne	s1,s2,.L115
	lui	s0,%hi(gRooms)
	addi	s0,s0,%lo(gRooms)
	addi	s8,s0,16
	mv	s6,s0
	li	s7,1
.L123:
	lbu	s5,2(s6)
	lbu	a5,0(s6)
	lbu	s3,3(s6)
	srli	s5,s5,1
	add	s5,s5,a5
	lbu	a5,1(s6)
	lbu	s2,6(s6)
	srli	s3,s3,1
	add	s3,s3,a5
	lbu	a5,4(s6)
	lbu	s1,7(s6)
	srli	s2,s2,1
	add	s2,s2,a5
	lbu	a5,5(s6)
	srli	s1,s1,1
	add	s1,s1,a5
	call	rng_next
	andi	a0,a0,1
	bne	a0,zero,.L116
	mv	a5,s2
	bgtu	s5,s2,.L117
	mv	a5,s5
	mv	s5,s2
.L117:
	slli	a4,s3,4
	sub	a4,a4,s3
	slli	a4,a4,1
.L118:
	bleu	a5,s5,.L119
	bgtu	s3,s1,.L121
	mv	a5,s1
	mv	s1,s3
	mv	s3,a5
.L121:
	bleu	s1,s3,.L122
.L131:
	addi	s6,s6,4
	bne	s8,s6,.L123
	call	rng_next
	li	a1,5
	call	__umodsi3
	mv	s8,a0
	call	rng_next
	andi	a0,a0,3
	sltu	a5,a0,s8
	seqz	a5,a5
	add	a0,a0,a5
	slli	a5,s8,2
	add	a5,s0,a5
	lbu	a4,2(a5)
	lbu	a3,0(a5)
	slli	a0,a0,2
	srli	a4,a4,1
	add	a4,a4,a3
	lui	a3,%hi(gPlayerX)
	sb	a4,%lo(gPlayerX)(a3)
	lbu	a4,3(a5)
	lbu	a5,1(a5)
	add	a0,s0,a0
	srli	a4,a4,1
	add	a5,a4,a5
	lui	a4,%hi(gPlayerY)
	sb	a5,%lo(gPlayerY)(a4)
	lbu	a4,2(a0)
	lbu	a5,0(a0)
	lbu	a3,1(a0)
	srli	a4,a4,1
	add	a4,a4,a5
	andi	a4,a4,0xff
	lui	a5,%hi(gStairsX)
	sb	a4,%lo(gStairsX)(a5)
	lbu	a5,3(a0)
	srli	a5,a5,1
	add	a5,a5,a3
	andi	a5,a5,0xff
	lui	a3,%hi(gStairsY)
	sb	a5,%lo(gStairsY)(a3)
	slli	a3,a5,4
	sub	a5,a3,a5
	slli	a5,a5,1
	add	s4,s4,a5
	add	s4,s4,a4
	li	a5,2
	lui	a4,%hi(gFloor)
	sb	a5,0(s4)
	lbu	s4,%lo(gFloor)(a4)
	bleu	s4,a5,.L149
	sltiu	a4,s4,5
	seqz	a4,a4
.L133:
	add	a5,a4,a5
	lui	s5,%hi(gEnemyCount)
	lui	s6,%hi(gGoldCount)
	lui	s7,%hi(gEnemies)
	sw	a5,12(sp)
	sb	zero,%lo(gEnemyCount)(s5)
	sb	zero,%lo(gGoldCount)(s6)
	li	s3,0
	li	s9,1
	li	s10,11
	addi	s7,s7,%lo(gEnemies)
	li	s11,7
.L146:
	beq	s8,s3,.L135
	li	a4,1
	bleu	s4,s9,.L136
	call	rng_next
	andi	a0,a0,1
	li	a4,2
	sub	a4,a4,a0
.L136:
	li	a3,0
.L137:
	lbu	s2,%lo(gEnemyCount)(s5)
	bgtu	s2,s10,.L143
	li	a5,10
.L139:
	lbu	a0,2(s0)
	lbu	s1,0(s0)
	sw	a5,28(sp)
	sw	a4,24(sp)
	sw	a3,20(sp)
	call	rng_range
	lbu	a1,1(s0)
	add	s1,s1,a0
	lbu	a0,3(s0)
	sw	a1,16(sp)
	call	rng_range
	lw	a1,16(sp)
	add	a1,a1,a0
	andi	a1,a1,0xff
	andi	a0,s1,0xff
	sw	a1,16(sp)
	call	spawn_blocked
	lw	a1,16(sp)
	lw	a3,20(sp)
	lw	a4,24(sp)
	lw	a5,28(sp)
	beq	a0,zero,.L138
	addi	a5,a5,-1
	bne	a5,zero,.L139
.L140:
	addi	a3,a3,1
	bne	a3,a4,.L137
.L143:
	lbu	s1,%lo(gGoldCount)(s6)
	bgtu	s1,s11,.L135
	call	rng_next
	li	a1,100
	call	__umodsi3
	li	a5,74
	bgtu	a0,a5,.L135
	li	a5,10
.L145:
	lbu	a0,2(s0)
	lbu	s2,0(s0)
	sw	a5,20(sp)
	call	rng_range
	lbu	a1,1(s0)
	add	s2,s2,a0
	lbu	a0,3(s0)
	sw	a1,16(sp)
	andi	s2,s2,0xff
	call	rng_range
	lw	a1,16(sp)
	add	a1,a1,a0
	andi	a1,a1,0xff
	mv	a0,s2
	sw	a1,16(sp)
	call	spawn_blocked
	lw	a1,16(sp)
	beq	a0,zero,.L144
	lw	a5,20(sp)
	addi	a5,a5,-1
	bne	a5,zero,.L145
.L135:
	addi	s3,s3,1
	li	a5,5
	addi	s0,s0,4
	bne	s3,a5,.L146
	lw	ra,92(sp)
	lw	s0,88(sp)
	lw	s1,84(sp)
	lw	s2,80(sp)
	lw	s3,76(sp)
	lw	s4,72(sp)
	lw	s5,68(sp)
	lw	s6,64(sp)
	lw	s7,60(sp)
	lw	s8,56(sp)
	lw	s9,52(sp)
	lw	s10,48(sp)
	lw	s11,44(sp)
	addi	sp,sp,96
	jr	ra
.L119:
	add	a3,a4,a5
	add	a3,s4,a3
	sb	s7,0(a3)
	addi	a5,a5,1
	j	.L118
.L122:
	slli	a5,s1,4
	sub	a5,a5,s1
	slli	a5,a5,1
	add	a5,a5,s2
	add	a5,s4,a5
	sb	s7,0(a5)
	addi	s1,s1,1
	j	.L121
.L116:
	mv	a4,s1
	bgtu	s3,s1,.L126
	mv	a4,s3
	mv	s3,s1
.L126:
	bleu	a4,s3,.L127
	bgtu	s5,s2,.L128
	mv	a5,s2
	mv	s2,s5
	mv	s5,a5
.L128:
	slli	a5,s1,4
	sub	a5,a5,s1
	slli	a5,a5,1
.L129:
	bgtu	s2,s5,.L131
	add	a4,a5,s2
	add	a4,s4,a4
	sb	s7,0(a4)
	addi	s2,s2,1
	j	.L129
.L127:
	slli	a5,a4,4
	sub	a5,a5,a4
	slli	a5,a5,1
	add	a5,a5,s5
	add	a5,s4,a5
	sb	s7,0(a5)
	addi	a4,a4,1
	j	.L126
.L149:
	li	a5,1
	li	a4,0
	j	.L133
.L138:
	slli	a5,s2,1
	lw	a2,12(sp)
	add	a5,a5,s2
	add	a5,s7,a5
	addi	s2,s2,1
	sb	s1,0(a5)
	sb	a1,1(a5)
	sb	a2,2(a5)
	sb	s2,%lo(gEnemyCount)(s5)
	j	.L140
.L144:
	slli	a4,s1,1
	lui	a5,%hi(gGold)
	add	a4,a4,s1
	addi	a5,a5,%lo(gGold)
	add	a5,a5,a4
	sb	s2,0(a5)
	sb	a1,1(a5)
	sw	a5,16(sp)
	call	rng_next
	lw	a5,16(sp)
	slli	a4,s4,1
	addi	a4,a4,5
	andi	a0,a0,7
	add	a4,a4,a0
	addi	s1,s1,1
	sb	a4,2(a5)
	sb	s1,%lo(gGoldCount)(s6)
	j	.L135
	.size	build_floor, .-build_floor
	.section	.text.game_reset,"ax",@progbits
	.align	2
	.type	game_reset, @function
game_reset:
	lui	a3,%hi(gTurnCount)
	lui	a2,%hi(gGoldTotal)
	lw	a4,%lo(gGoldTotal)(a2)
	lw	a5,%lo(gTurnCount)(a3)
	lui	a1,%hi(gFloor)
	lui	a0,%hi(gRngState)
	add	a5,a5,a4
	li	a4,-1640529920
	addi	a4,a4,-1607
	add	a5,a5,a4
	lbu	a4,%lo(gFloor)(a1)
	lw	a6,%lo(gRngState)(a0)
	addi	sp,sp,-16
	add	a5,a5,a4
	sw	ra,12(sp)
	xor	a4,a5,a6
	bne	a5,a6,.L163
	li	a4,324509696
	addi	a4,a4,-1057
.L163:
	sw	a4,%lo(gRngState)(a0)
	lui	a5,%hi(gPlayerHp)
	li	a4,9
	sb	a4,%lo(gPlayerHp)(a5)
	li	a5,1
	sb	a5,%lo(gFloor)(a1)
	lui	a5,%hi(gGameOver)
	sb	zero,%lo(gGameOver)(a5)
	lui	a5,%hi(gGameWon)
	sb	zero,%lo(gGameWon)(a5)
	sw	zero,%lo(gGoldTotal)(a2)
	sw	zero,%lo(gTurnCount)(a3)
	call	build_floor
	call	fnd_write_gold
	lw	ra,12(sp)
	lui	a5,%hi(gMessageId)
	li	a4,12
	sb	a4,%lo(gMessageId)(a5)
	lui	a5,%hi(gMessageValue)
	sw	zero,%lo(gMessageValue)(a5)
	addi	sp,sp,16
	jr	ra
	.size	game_reset, .-game_reset
	.section	.text.memcpy,"ax",@progbits
	.align	2
	.globl	memcpy
	.type	memcpy, @function
memcpy:
	li	a5,0
.L168:
	bne	a2,a5,.L169
	ret
.L169:
	add	a4,a1,a5
	lbu	a3,0(a4)
	add	a4,a0,a5
	addi	a5,a5,1
	sb	a3,0(a4)
	j	.L168
	.size	memcpy, .-memcpy
	.section	.rodata.main.str1.4,"aMS",@progbits,1
	.align	2
.LC0:
	.string	"RV32I MICRO ROGUELIKE"
	.align	2
.LC1:
	.string	"HP "
	.align	2
.LC2:
	.string	"/"
	.align	2
.LC3:
	.string	"  FLOOR "
	.align	2
.LC4:
	.string	"  GOLD "
	.align	2
.LC5:
	.string	"  TURN "
	.align	2
.LC6:
	.string	"You collect "
	.align	2
.LC7:
	.string	" gold."
	.align	2
.LC8:
	.string	"You wound the goblin."
	.align	2
.LC9:
	.string	"You slay the goblin."
	.align	2
.LC10:
	.string	"The dungeon bites back. Damage "
	.align	2
.LC11:
	.string	"."
	.align	2
.LC12:
	.string	"Stairs found. Press X to descend."
	.align	2
.LC13:
	.string	"You descend to floor "
	.align	2
.LC14:
	.string	"A wall blocks your path."
	.align	2
.LC15:
	.string	"You wait and listen."
	.align	2
.LC16:
	.string	"No stairs here."
	.align	2
.LC17:
	.string	"You escape rich. Gold "
	.align	2
.LC18:
	.string	". Press R."
	.align	2
.LC19:
	.string	"You died. Gold "
	.align	2
.LC20:
	.string	"New run begins."
	.align	2
.LC21:
	.string	"Reach floor "
	.align	2
.LC22:
	.string	" and escape alive."
	.align	2
.LC23:
	.string	"GAME OVER  R restart"
	.align	2
.LC24:
	.string	"VICTORY  R restart"
	.align	2
.LC25:
	.string	"WASD move  QEZC diag  X stairs  . or SPACE wait  R reset"
	.section	.text.startup.main,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-112
	li	a5,1073750016
	li	a4,1
	sw	ra,108(sp)
	sw	s0,104(sp)
	sw	s1,100(sp)
	sw	s2,96(sp)
	sw	s3,92(sp)
	sw	s4,88(sp)
	sw	s5,84(sp)
	sw	s6,80(sp)
	sw	s7,76(sp)
	sw	s8,72(sp)
	sw	s9,68(sp)
	sw	s10,64(sp)
	sw	s11,60(sp)
	sw	a4,12(a5)
	lui	a3,%hi(gRngState)
	lw	a2,%lo(gRngState)(a3)
	li	a4,-1029693440
	addi	a4,a4,1690
	xor	a5,a2,a4
	bne	a2,a4,.L171
	li	a5,324509696
	addi	a5,a5,-1057
.L171:
	li	a0,27
	sw	a5,%lo(gRngState)(a3)
	call	uart_putc
	li	a0,91
	call	uart_putc
	li	a0,50
	call	uart_putc
	li	a0,74
	call	uart_putc
	call	term_home
	li	a0,27
	call	uart_putc
	li	a0,91
	call	uart_putc
	li	a0,63
	call	uart_putc
	li	a0,50
	call	uart_putc
	li	a0,53
	call	uart_putc
	li	a0,108
	lui	s1,%hi(gMessageId)
	call	uart_putc
	sb	zero,%lo(gMessageId)(s1)
	call	game_reset
	lui	a5,%hi(.LC0)
	addi	a5,a5,%lo(.LC0)
	sw	a5,24(sp)
	lui	a5,%hi(gMap)
	addi	a5,a5,%lo(gMap)
	sw	a5,16(sp)
.L172:
	call	term_home
	lw	a0,24(sp)
	lui	s4,%hi(gPlayerHp)
	lui	s10,%hi(gFloor)
	call	emit_str
	call	emit_crlf
	lui	a0,%hi(.LC1)
	addi	a0,a0,%lo(.LC1)
	call	emit_str
	lbu	s0,%lo(gPlayerHp)(s4)
	lui	s7,%hi(gGoldTotal)
	lui	s9,%hi(gTurnCount)
	mv	a0,s0
	call	emit_dec_u32
	lui	a0,%hi(.LC2)
	addi	a0,a0,%lo(.LC2)
	call	emit_str
	li	a0,9
	call	emit_dec_u32
	lui	a0,%hi(.LC3)
	addi	a0,a0,%lo(.LC3)
	call	emit_str
	lbu	s2,%lo(gFloor)(s10)
	li	s5,0
	li	s3,0
	mv	a0,s2
	call	emit_dec_u32
	lui	a0,%hi(.LC4)
	addi	a0,a0,%lo(.LC4)
	call	emit_str
	lw	a5,%lo(gGoldTotal)(s7)
	mv	a0,a5
	sw	a5,8(sp)
	call	emit_dec_u32
	lui	a0,%hi(.LC5)
	addi	a0,a0,%lo(.LC5)
	call	emit_str
	lw	a5,%lo(gTurnCount)(s9)
	mv	a0,a5
	sw	a5,12(sp)
	call	emit_dec_u32
	call	emit_crlf
	call	emit_border
.L177:
	li	a0,124
	call	uart_putc
	lw	a5,16(sp)
	li	s6,0
	lui	s8,%hi(gPlayerX)
	add	a5,s5,a5
	sw	a5,20(sp)
.L176:
	lbu	s11,%lo(gPlayerX)(s8)
	bne	s11,s6,.L173
	lui	a5,%hi(gPlayerY)
	lbu	a3,%lo(gPlayerY)(a5)
	li	a5,64
	beq	a3,s3,.L174
.L173:
	mv	a1,s3
	mv	a0,s6
	call	enemy_at
	li	a5,-1
	mv	a3,a0
	beq	a0,a5,.L175
	slli	a0,a0,1
	lui	a5,%hi(gEnemies)
	add	a0,a0,a3
	addi	a5,a5,%lo(gEnemies)
	add	a0,a5,a0
	lbu	a2,2(a0)
	li	a3,2
	li	a5,79
	bgtu	a2,a3,.L174
	li	a5,71
	beq	a2,a3,.L174
	li	a5,103
.L174:
	mv	a0,a5
	call	uart_putc
	addi	s6,s6,1
	li	a5,30
	bne	s6,a5,.L176
	li	a0,124
	call	uart_putc
	call	emit_crlf
	addi	s3,s3,1
	li	a5,14
	add	s5,s5,s6
	bne	s3,a5,.L177
	call	emit_border
	lbu	a5,%lo(gMessageId)(s1)
	li	a4,7
	beq	a5,a4,.L178
	bgtu	a5,a4,.L179
	li	a4,4
	beq	a5,a4,.L180
	bgtu	a5,a4,.L181
	li	a4,2
	beq	a5,a4,.L182
	li	a4,3
	beq	a5,a4,.L183
	li	a4,1
	beq	a5,a4,.L184
.L185:
	lui	a0,%hi(.LC21)
	addi	a0,a0,%lo(.LC21)
	call	emit_str
	li	a0,5
	call	emit_dec_u32
	lui	a0,%hi(.LC22)
	addi	a0,a0,%lo(.LC22)
	j	.L280
.L175:
	sw	a0,28(sp)
	mv	a1,s3
	mv	a0,s6
	call	gold_at
	lw	a3,28(sp)
	li	a5,36
	bne	a0,a3,.L174
	lw	a5,20(sp)
	add	a5,a5,s6
	lbu	a3,0(a5)
	li	a5,35
	beq	a3,zero,.L174
	li	a2,2
	li	a5,62
	beq	a3,a2,.L174
	li	a5,46
	j	.L174
.L181:
	li	a4,5
	bne	a5,a4,.L274
	lui	a0,%hi(.LC12)
	addi	a0,a0,%lo(.LC12)
	j	.L280
.L179:
	li	a4,10
	beq	a5,a4,.L188
	bgtu	a5,a4,.L189
	li	a4,8
	bne	a5,a4,.L275
	lui	a0,%hi(.LC15)
	addi	a0,a0,%lo(.LC15)
	j	.L280
.L189:
	li	a4,11
	beq	a5,a4,.L192
	li	a4,12
	bne	a5,a4,.L185
	lui	a0,%hi(.LC20)
	addi	a0,a0,%lo(.LC20)
	j	.L280
.L184:
	lui	a0,%hi(.LC6)
	addi	a0,a0,%lo(.LC6)
	call	emit_str
	lui	a5,%hi(gMessageValue)
	lw	a0,%lo(gMessageValue)(a5)
	call	emit_dec_u32
	lui	a0,%hi(.LC7)
	addi	a0,a0,%lo(.LC7)
.L280:
	lui	s5,%hi(gGameOver)
	call	emit_str
	call	emit_crlf
	lbu	s3,%lo(gGameOver)(s5)
	beq	s3,zero,.L195
	lui	a0,%hi(.LC23)
	addi	a0,a0,%lo(.LC23)
.L281:
	call	emit_str
	call	emit_crlf
	li	a4,1073741824
	addi	a4,a4,4
.L198:
	lw	a5,0(a4)
	andi	a5,a5,1
	beq	a5,zero,.L198
	li	a5,1073741824
	lw	a3,12(a5)
	li	a4,82
	andi	a5,a3,223
	bne	a5,a4,.L199
	call	game_reset
	j	.L172
.L182:
	lui	a0,%hi(.LC8)
	addi	a0,a0,%lo(.LC8)
	j	.L280
.L183:
	lui	a0,%hi(.LC9)
	addi	a0,a0,%lo(.LC9)
	j	.L280
.L180:
	lui	a0,%hi(.LC10)
	addi	a0,a0,%lo(.LC10)
.L286:
	call	emit_str
	lui	a5,%hi(gMessageValue)
	lw	a0,%lo(gMessageValue)(a5)
	call	emit_dec_u32
	lui	a0,%hi(.LC11)
	addi	a0,a0,%lo(.LC11)
	j	.L280
.L274:
	lui	a0,%hi(.LC13)
	addi	a0,a0,%lo(.LC13)
	j	.L286
.L178:
	lui	a0,%hi(.LC14)
	addi	a0,a0,%lo(.LC14)
	j	.L280
.L275:
	lui	a0,%hi(.LC16)
	addi	a0,a0,%lo(.LC16)
	j	.L280
.L188:
	lui	a0,%hi(.LC17)
	addi	a0,a0,%lo(.LC17)
.L285:
	call	emit_str
	lui	a5,%hi(gMessageValue)
	lw	a0,%lo(gMessageValue)(a5)
	call	emit_dec_u32
	lui	a0,%hi(.LC18)
	addi	a0,a0,%lo(.LC18)
	j	.L280
.L192:
	lui	a0,%hi(.LC19)
	addi	a0,a0,%lo(.LC19)
	j	.L285
.L195:
	lui	a5,%hi(gGameWon)
	lbu	a5,%lo(gGameWon)(a5)
	beq	a5,zero,.L197
	lui	a0,%hi(.LC24)
	addi	a0,a0,%lo(.LC24)
	j	.L281
.L197:
	lui	a0,%hi(.LC25)
	addi	a0,a0,%lo(.LC25)
	j	.L281
.L199:
	lui	a0,%hi(gGameWon)
	lbu	a4,%lo(gGameWon)(a0)
	or	s3,s3,a4
	bne	s3,zero,.L172
	andi	a4,a3,255
	addi	a1,a4,-13
	addi	a2,a4,-62
	seqz	a2,a2
	seqz	a1,a1
	or	a1,a1,a2
	addi	a2,a5,-88
	seqz	a2,a2
	or	a2,a2,a1
	bne	a2,zero,.L248
	addi	a2,a4,-10
	bne	a2,zero,.L202
.L248:
	lui	a5,%hi(gStairsX)
	lbu	a5,%lo(gStairsX)(a5)
	lui	s3,%hi(gMessageValue)
	bne	a5,s11,.L204
	lui	a5,%hi(gPlayerY)
	lbu	a4,%lo(gPlayerY)(a5)
	lui	a5,%hi(gStairsY)
	lbu	a5,%lo(gStairsY)(a5)
	beq	a4,a5,.L205
.L204:
	li	a5,9
	sb	a5,%lo(gMessageId)(s1)
	sw	zero,%lo(gMessageValue)(s3)
	j	.L172
.L205:
	li	a5,4
	bleu	s2,a5,.L206
	li	a5,1
	sb	a5,%lo(gGameWon)(a0)
	li	a5,10
	sb	a5,%lo(gMessageId)(s1)
	lw	a5,8(sp)
	sw	a5,%lo(gMessageValue)(s3)
	j	.L172
.L206:
	addi	s2,s2,1
	andi	s2,s2,0xff
	sb	s2,%lo(gFloor)(s10)
	li	a5,8
	bgtu	s0,a5,.L207
	addi	s0,s0,1
	andi	s0,s0,0xff
	sb	s0,%lo(gPlayerHp)(s4)
.L207:
	call	build_floor
	li	a5,6
	sb	a5,%lo(gMessageId)(s1)
	sw	s2,%lo(gMessageValue)(s3)
.L208:
	lbu	a4,%lo(gMessageId)(s1)
	li	a5,6
	beq	a4,a5,.L172
	lw	a5,12(sp)
	sw	zero,44(sp)
	li	s2,0
	addi	a5,a5,1
	sw	a5,%lo(gTurnCount)(s9)
	lui	a5,%hi(gEnemies)
	addi	s10,a5,%lo(gEnemies)
	li	s11,1
.L225:
	lui	a5,%hi(gEnemyCount)
	lbu	a5,%lo(gEnemyCount)(a5)
	bltu	s2,a5,.L236
	lw	a5,44(sp)
	beq	a5,zero,.L172
	lui	a4,%hi(gMessageValue)
	bltu	a5,s0,.L238
	lw	a5,%lo(gGoldTotal)(s7)
	li	a3,1
	sb	a3,%lo(gGameOver)(s5)
	sb	zero,%lo(gPlayerHp)(s4)
	li	a3,11
.L279:
	sb	a3,%lo(gMessageId)(s1)
	sw	a5,%lo(gMessageValue)(a4)
	j	.L172
.L202:
	addi	a2,a4,-46
	beq	a2,zero,.L249
	addi	a4,a4,-32
	bne	a4,zero,.L209
.L249:
	li	a5,8
	sb	a5,%lo(gMessageId)(s1)
	lui	a5,%hi(gMessageValue)
	sw	zero,%lo(gMessageValue)(a5)
	j	.L208
.L209:
	addi	a4,a5,-75
	beq	a4,zero,.L250
	addi	a4,a5,-87
	bne	a4,zero,.L212
.L250:
	li	a1,-1
.L288:
	li	a0,0
.L283:
	call	attempt_move_player
	bne	a0,zero,.L208
	j	.L172
.L212:
	addi	a4,a5,-74
	beq	a4,zero,.L251
	addi	a4,a5,-83
	bne	a4,zero,.L215
.L251:
	li	a1,1
	j	.L288
.L215:
	addi	a4,a5,-65
	beq	a4,zero,.L252
	addi	a4,a5,-72
	bne	a4,zero,.L217
.L252:
	li	a1,0
.L287:
	li	a0,-1
	j	.L283
.L217:
	andi	a4,a3,215
	li	a2,68
	li	a1,0
	beq	a4,a2,.L289
	li	a2,81
	li	a1,-1
	beq	a4,a2,.L282
	andi	a3,a3,207
	li	a4,69
	bne	a3,a4,.L221
	li	a1,-1
.L289:
	li	a0,1
	j	.L283
.L221:
	addi	a4,a5,-66
	beq	a4,zero,.L253
	addi	a4,a5,-90
	bne	a4,zero,.L222
.L253:
	li	a1,1
	j	.L287
.L222:
	addi	a4,a5,-67
	beq	a4,zero,.L254
	addi	a5,a5,-78
	bne	a5,zero,.L172
.L254:
	li	a1,1
.L282:
	mv	a0,a1
	j	.L283
.L236:
	lbu	a5,0(s10)
	lbu	a4,%lo(gPlayerX)(s8)
	lbu	a3,1(s10)
	li	s3,-1
	sub	a4,a4,a5
	lui	a5,%hi(gPlayerY)
	lbu	a5,%lo(gPlayerY)(a5)
	sub	a5,a5,a3
	blt	a4,zero,.L226
	snez	s3,a4
.L226:
	li	s9,-1
	blt	a5,zero,.L227
	snez	s9,a5
.L227:
	srai	a3,a4,31
	xor	a4,a3,a4
	sub	a4,a4,a3
	bgt	a4,s11,.L228
	srai	a2,a5,31
	xor	a3,a2,a5
	sub	a3,a3,a2
	bgt	a3,s11,.L228
	lw	a5,44(sp)
	addi	a5,a5,1
	sw	a5,44(sp)
.L229:
	addi	s2,s2,1
	addi	s10,s10,3
	j	.L225
.L228:
	beq	s9,zero,.L234
	bne	s3,zero,.L230
.L234:
	srai	a3,a5,31
	xor	a5,a3,a5
	sub	a5,a5,a3
	bge	a4,a5,.L232
	addi	a3,sp,44
	mv	a2,s9
	li	a1,0
	mv	a0,s2
	call	enemy_try_step
	bne	a0,zero,.L229
	addi	a3,sp,44
	li	a2,0
	mv	a1,s3
	j	.L284
.L230:
	addi	a3,sp,44
	mv	a2,s9
	mv	a1,s3
	mv	a0,s2
	sw	a4,12(sp)
	sw	a5,8(sp)
	call	enemy_try_step
	lw	a5,8(sp)
	lw	a4,12(sp)
	beq	a0,zero,.L234
	j	.L229
.L232:
	addi	a3,sp,44
	li	a2,0
	mv	a1,s3
	mv	a0,s2
	call	enemy_try_step
	bne	a0,zero,.L229
	addi	a3,sp,44
	mv	a2,s9
	li	a1,0
.L284:
	mv	a0,s2
	call	enemy_try_step
	j	.L229
.L238:
	sub	s0,s0,a5
	sb	s0,%lo(gPlayerHp)(s4)
	li	a3,4
	j	.L279
	.size	main, .-main
	.section	.bss.gMessageValue,"aw",@nobits
	.align	2
	.type	gMessageValue, @object
	.size	gMessageValue, 4
gMessageValue:
	.zero	4
	.section	.bss.gMessageId,"aw",@nobits
	.type	gMessageId, @object
	.size	gMessageId, 1
gMessageId:
	.zero	1
	.section	.bss.gRngState,"aw",@nobits
	.align	2
	.type	gRngState, @object
	.size	gRngState, 4
gRngState:
	.zero	4
	.section	.bss.gTurnCount,"aw",@nobits
	.align	2
	.type	gTurnCount, @object
	.size	gTurnCount, 4
gTurnCount:
	.zero	4
	.section	.bss.gGoldTotal,"aw",@nobits
	.align	2
	.type	gGoldTotal, @object
	.size	gGoldTotal, 4
gGoldTotal:
	.zero	4
	.section	.bss.gGameWon,"aw",@nobits
	.type	gGameWon, @object
	.size	gGameWon, 1
gGameWon:
	.zero	1
	.section	.bss.gGameOver,"aw",@nobits
	.type	gGameOver, @object
	.size	gGameOver, 1
gGameOver:
	.zero	1
	.section	.bss.gStairsY,"aw",@nobits
	.type	gStairsY, @object
	.size	gStairsY, 1
gStairsY:
	.zero	1
	.section	.bss.gStairsX,"aw",@nobits
	.type	gStairsX, @object
	.size	gStairsX, 1
gStairsX:
	.zero	1
	.section	.bss.gFloor,"aw",@nobits
	.type	gFloor, @object
	.size	gFloor, 1
gFloor:
	.zero	1
	.section	.bss.gPlayerHp,"aw",@nobits
	.type	gPlayerHp, @object
	.size	gPlayerHp, 1
gPlayerHp:
	.zero	1
	.section	.bss.gPlayerY,"aw",@nobits
	.type	gPlayerY, @object
	.size	gPlayerY, 1
gPlayerY:
	.zero	1
	.section	.bss.gPlayerX,"aw",@nobits
	.type	gPlayerX, @object
	.size	gPlayerX, 1
gPlayerX:
	.zero	1
	.section	.bss.gGoldCount,"aw",@nobits
	.type	gGoldCount, @object
	.size	gGoldCount, 1
gGoldCount:
	.zero	1
	.section	.bss.gEnemyCount,"aw",@nobits
	.type	gEnemyCount, @object
	.size	gEnemyCount, 1
gEnemyCount:
	.zero	1
	.section	.bss.gGold,"aw",@nobits
	.align	2
	.type	gGold, @object
	.size	gGold, 24
gGold:
	.zero	24
	.section	.bss.gEnemies,"aw",@nobits
	.align	2
	.type	gEnemies, @object
	.size	gEnemies, 36
gEnemies:
	.zero	36
	.section	.bss.gRooms,"aw",@nobits
	.align	2
	.type	gRooms, @object
	.size	gRooms, 20
gRooms:
	.zero	20
	.section	.bss.gMap,"aw",@nobits
	.align	2
	.type	gMap, @object
	.size	gMap, 420
gMap:
	.zero	420
	.globl	__udivsi3
	.globl	__umodsi3
	.ident	"GCC: (xPack GNU RISC-V Embedded GCC x86_64) 15.2.0"
	.section	.note.GNU-stack,"",@progbits
