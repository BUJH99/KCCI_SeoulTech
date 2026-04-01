	.file	"tetris_port.c"
	.option nopic
	.attribute arch, "rv32i2p1"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.section	.text.uart_putc,"ax",@progbits
	.align	2
	.type	uart_putc, @function
uart_putc:
	li	a4,1073741824
	addi	a4,a4,4
.L2:
	lw	a5,0(a4)
	andi	a5,a5,2
	beq	a5,zero,.L2
	li	a5,1073741824
	sw	a0,8(a5)
	ret
	.size	uart_putc, .-uart_putc
	.section	.text.term_crlf,"ax",@progbits
	.align	2
	.type	term_crlf, @function
term_crlf:
	addi	sp,sp,-16
	li	a0,13
	sw	ra,12(sp)
	call	uart_putc
	lw	ra,12(sp)
	li	a0,10
	addi	sp,sp,16
	tail	uart_putc
	.size	term_crlf, .-term_crlf
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
	.section	.text.piece_has_block,"ax",@progbits
	.align	2
	.type	piece_has_block, @function
piece_has_block:
	or	a5,a2,a3
	li	t1,3
	bgtu	a5,t1,.L17
	bne	a0,zero,.L11
	li	a5,8192
	andi	a1,a1,1
	addi	a5,a5,546
	bne	a1,zero,.L12
	li	a5,240
.L12:
	slli	a3,a3,2
	add	a3,a3,a2
	li	a0,1
	sll	a0,a0,a3
	and	a0,a0,a5
	snez	a0,a0
	ret
.L11:
	li	a6,1
	li	a5,102
	beq	a0,a6,.L12
	li	a7,2
	andi	a4,a1,3
	bne	a0,a7,.L13
	li	a5,114
	beq	a4,zero,.L12
	li	a5,610
	beq	a4,a6,.L12
	li	a5,562
	bne	a4,a0,.L12
	li	a5,624
	j	.L12
.L13:
	bne	a0,t1,.L14
	slli	a5,a1,31
	srai	a1,a5,31
	andi	a5,a1,1068
	addi	a5,a5,54
	j	.L12
.L14:
	li	a5,4
	bne	a0,a5,.L15
	slli	a5,a1,31
	srai	a1,a5,31
	andi	a5,a1,513
	addi	a5,a5,99
	j	.L12
.L15:
	li	a5,5
	bne	a0,a5,.L16
	li	a5,113
	beq	a4,zero,.L12
	li	a5,550
	beq	a4,a6,.L12
	li	a5,802
	bne	a4,a7,.L12
	li	a5,1136
	j	.L12
.L16:
	li	a5,116
	beq	a4,zero,.L12
	li	a5,1570
	beq	a4,a6,.L12
	li	a5,368
	beq	a4,a7,.L12
	li	a5,547
	j	.L12
.L17:
	li	a0,0
	ret
	.size	piece_has_block, .-piece_has_block
	.section	.text.piece_fits,"ax",@progbits
	.align	2
	.type	piece_fits, @function
piece_fits:
	addi	sp,sp,-64
	sw	s0,56(sp)
	sw	s1,52(sp)
	slli	s0,a1,2
	lui	s1,%hi(gBoard)
	add	s0,s0,a1
	addi	s1,s1,%lo(gBoard)
	sw	s3,44(sp)
	sw	s5,36(sp)
	sw	s7,28(sp)
	sw	s8,24(sp)
	sw	s9,20(sp)
	sw	ra,60(sp)
	mv	s9,a3
	sw	s2,48(sp)
	sw	s4,40(sp)
	sw	s6,32(sp)
	mv	s5,a0
	mv	s3,a1
	mv	s8,a2
	slli	s0,s0,1
	li	a3,0
	add	s1,s1,a0
	li	s7,4
.L32:
	add	s4,a3,s3
	slti	s2,s4,16
	xori	s2,s2,1
	li	a2,0
	add	s6,s1,s0
.L35:
	mv	a1,s9
	mv	a0,s8
	sw	a3,12(sp)
	sw	a2,8(sp)
	call	piece_has_block
	lw	a2,8(sp)
	lw	a3,12(sp)
	beq	a0,zero,.L33
	add	a5,a2,s5
	sltiu	a5,a5,10
	beq	a5,zero,.L37
	bne	s2,zero,.L37
	blt	s4,zero,.L33
	add	a5,s6,a2
	lbu	a5,0(a5)
	bne	a5,zero,.L37
.L33:
	addi	a2,a2,1
	bne	a2,s7,.L35
	addi	a3,a3,1
	addi	s0,s0,10
	bne	a3,a2,.L32
	li	a0,1
	j	.L31
.L37:
	li	a0,0
.L31:
	lw	ra,60(sp)
	lw	s0,56(sp)
	lw	s1,52(sp)
	lw	s2,48(sp)
	lw	s3,44(sp)
	lw	s4,40(sp)
	lw	s5,36(sp)
	lw	s6,32(sp)
	lw	s7,28(sp)
	lw	s8,24(sp)
	lw	s9,20(sp)
	addi	sp,sp,64
	jr	ra
	.size	piece_fits, .-piece_fits
	.section	.text.score_to_fnd,"ax",@progbits
	.align	2
	.type	score_to_fnd, @function
score_to_fnd:
	lui	a5,%hi(gScore)
	lw	a5,%lo(gScore)(a5)
	li	a4,8192
	addi	a4,a4,1807
	bleu	a5,a4,.L45
	mv	a5,a4
.L45:
	li	a4,0
	li	a3,999
.L46:
	bgtu	a5,a3,.L47
	li	a2,0
	li	a3,99
.L48:
	bgtu	a5,a3,.L49
	li	a3,0
	li	a1,9
.L50:
	bgtu	a5,a1,.L51
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
.L47:
	addi	a5,a5,-1000
	addi	a4,a4,1
	j	.L46
.L49:
	addi	a5,a5,-100
	addi	a2,a2,1
	j	.L48
.L51:
	addi	a5,a5,-10
	addi	a3,a3,1
	j	.L50
	.size	score_to_fnd, .-score_to_fnd
	.section	.text.score_add,"ax",@progbits
	.align	2
	.type	score_add, @function
score_add:
	lui	a4,%hi(gScore)
	lw	a5,%lo(gScore)(a4)
	add	a0,a5,a0
	li	a5,8192
	addi	a5,a5,1807
	bleu	a0,a5,.L53
	mv	a0,a5
.L53:
	sw	a0,%lo(gScore)(a4)
	tail	score_to_fnd
	.size	score_add, .-score_add
	.section	.text.gravity_reload,"ax",@progbits
	.align	2
	.type	gravity_reload, @function
gravity_reload:
	lui	a5,%hi(gLines)
	lw	a5,%lo(gLines)(a5)
	li	a4,3
	li	a0,120
	bleu	a5,a4,.L54
	li	a4,7
	li	a0,95
	bleu	a5,a4,.L54
	li	a4,11
	li	a0,75
	bleu	a5,a4,.L54
	li	a4,15
	li	a0,60
	bleu	a5,a4,.L54
	li	a4,19
	li	a0,48
	bleu	a5,a4,.L54
	li	a0,36
.L54:
	ret
	.size	gravity_reload, .-gravity_reload
	.section	.text.spawn_piece,"ax",@progbits
	.align	2
	.type	spawn_piece, @function
spawn_piece:
	lui	a3,%hi(gRngState)
	lw	a5,%lo(gRngState)(a3)
	addi	sp,sp,-16
	sw	ra,12(sp)
	bne	a5,zero,.L62
	li	a5,324509696
	addi	a5,a5,-1057
.L62:
	slli	a4,a5,13
	xor	a4,a4,a5
	srli	a5,a4,17
	xor	a5,a5,a4
	slli	a2,a5,5
	xor	a2,a2,a5
	sw	a2,%lo(gRngState)(a3)
	li	a5,7
	andi	a2,a2,7
	bne	a2,a5,.L63
	li	a2,3
.L63:
	lui	a5,%hi(gPieceType)
	sw	a2,%lo(gPieceType)(a5)
	lui	a5,%hi(gPieceRot)
	sw	zero,%lo(gPieceRot)(a5)
	li	a0,3
	lui	a5,%hi(gPieceX)
	sw	a0,%lo(gPieceX)(a5)
	li	a3,0
	lui	a5,%hi(gPieceY)
	li	a1,0
	sw	zero,%lo(gPieceY)(a5)
	call	piece_fits
	bne	a0,zero,.L61
	lui	a5,%hi(gGameOver)
	li	a4,1
	sw	a4,%lo(gGameOver)(a5)
.L61:
	lw	ra,12(sp)
	addi	sp,sp,16
	jr	ra
	.size	spawn_piece, .-spawn_piece
	.section	.text.game_reset,"ax",@progbits
	.align	2
	.type	game_reset, @function
game_reset:
	addi	sp,sp,-16
	lui	a4,%hi(gBoard)
	sw	ra,12(sp)
	li	a5,0
	addi	a4,a4,%lo(gBoard)
	li	a3,160
.L69:
	add	a2,a5,a4
	sb	zero,0(a2)
	addi	a5,a5,1
	bne	a5,a3,.L69
	lui	a5,%hi(gScore)
	sw	zero,%lo(gScore)(a5)
	lui	a5,%hi(gLines)
	sw	zero,%lo(gLines)(a5)
	lui	a3,%hi(gRngState)
	lui	a5,%hi(gGameOver)
	li	a4,1
	sw	zero,%lo(gGameOver)(a5)
	lw	a2,%lo(gRngState)(a3)
	lui	a5,%hi(gNeedRedraw)
	sw	a4,%lo(gNeedRedraw)(a5)
	li	a4,-1640529920
	li	a5,610840576
	addi	a4,a4,-1607
	addi	a5,a5,-799
	beq	a2,a4,.L70
	xor	a5,a2,a4
.L70:
	sw	a5,%lo(gRngState)(a3)
	call	score_to_fnd
	call	gravity_reload
	lw	ra,12(sp)
	lui	a5,%hi(gGravityCounter)
	sw	a0,%lo(gGravityCounter)(a5)
	addi	sp,sp,16
	tail	spawn_piece
	.size	game_reset, .-game_reset
	.section	.text.draw_border,"ax",@progbits
	.align	2
	.type	draw_border, @function
draw_border:
	addi	sp,sp,-16
	li	a0,43
	sw	s0,8(sp)
	sw	ra,12(sp)
	li	s0,10
	call	uart_putc
.L75:
	li	a0,45
	addi	s0,s0,-1
	call	uart_putc
	bne	s0,zero,.L75
	li	a0,43
	call	uart_putc
	lw	s0,8(sp)
	lw	ra,12(sp)
	addi	sp,sp,16
	tail	term_crlf
	.size	draw_border, .-draw_border
	.section	.text.advance_game,"ax",@progbits
	.align	2
	.type	advance_game, @function
advance_game:
	addi	sp,sp,-64
	lui	a5,%hi(gPieceX)
	sw	s0,56(sp)
	sw	s3,44(sp)
	lui	s0,%hi(gPieceY)
	lw	s3,%lo(gPieceX)(a5)
	lui	a5,%hi(gPieceType)
	sw	s2,48(sp)
	sw	s7,28(sp)
	lw	s2,%lo(gPieceY)(s0)
	lw	s7,%lo(gPieceType)(a5)
	lui	a5,%hi(gPieceRot)
	sw	s8,24(sp)
	lw	s8,%lo(gPieceRot)(a5)
	sw	s1,52(sp)
	addi	s1,s2,1
	mv	a3,s8
	mv	a2,s7
	mv	a1,s1
	mv	a0,s3
	sw	ra,60(sp)
	sw	s4,40(sp)
	sw	s5,36(sp)
	sw	s6,32(sp)
	call	piece_fits
	beq	a0,zero,.L79
	sw	s1,%lo(gPieceY)(s0)
	lw	ra,60(sp)
	lw	s0,56(sp)
	lw	s1,52(sp)
	lw	s2,48(sp)
	lw	s3,44(sp)
	lw	s4,40(sp)
	lw	s5,36(sp)
	lw	s6,32(sp)
	lw	s7,28(sp)
	lw	s8,24(sp)
	addi	sp,sp,64
	jr	ra
.L79:
	slli	s0,s2,2
	lui	s1,%hi(gBoard)
	add	s0,s0,s2
	addi	s1,s1,%lo(gBoard)
	slli	s0,s0,1
	li	a3,0
	li	s5,4
	add	s1,s3,s1
	li	s6,1
.L83:
	add	s4,a3,s2
	sltiu	s4,s4,16
	li	a2,0
.L82:
	mv	a1,s8
	mv	a0,s7
	sw	a3,12(sp)
	sw	a2,8(sp)
	call	piece_has_block
	lw	a2,8(sp)
	lw	a3,12(sp)
	beq	a0,zero,.L81
	add	a5,s3,a2
	sltiu	a5,a5,10
	beq	a5,zero,.L81
	beq	s4,zero,.L81
	add	a5,s1,s0
	add	a5,a5,a2
	sb	s6,0(a5)
.L81:
	addi	a2,a2,1
	bne	a2,s5,.L82
	addi	a3,a3,1
	addi	s0,s0,10
	bne	a3,a2,.L83
	lui	a1,%hi(gBoard)
	li	a4,0
	li	a2,15
	addi	a1,a1,%lo(gBoard)
	li	a6,10
	li	t1,-1
.L84:
	slli	a3,a2,2
	add	a3,a3,a2
	slli	a3,a3,1
	mv	a5,a3
	li	a0,0
.L86:
	add	a7,a3,a0
	add	a7,a7,a1
	lbu	a7,0(a7)
	beq	a7,zero,.L85
	addi	a0,a0,1
	bne	a0,a6,.L86
	addi	a4,a4,1
	j	.L97
.L89:
	add	a3,a1,a5
	li	a0,0
.L88:
	lbu	a7,-10(a3)
	addi	a0,a0,1
	addi	a3,a3,1
	sb	a7,-1(a3)
	bne	a0,a6,.L88
	addi	a5,a5,-10
.L97:
	bne	a5,zero,.L89
.L90:
	add	a3,a1,a5
	sb	zero,0(a3)
	addi	a5,a5,1
	bne	a5,a6,.L90
	j	.L84
.L85:
	addi	a2,a2,-1
	bne	a2,t1,.L84
	beq	a4,zero,.L91
	lui	a3,%hi(gLines)
	lw	a5,%lo(gLines)(a3)
	li	a0,100
	add	a5,a5,a4
	sw	a5,%lo(gLines)(a3)
	li	a5,1
	beq	a4,a5,.L119
	li	a5,2
	li	a0,300
	beq	a4,a5,.L119
	li	a5,3
	li	a0,500
	beq	a4,a5,.L119
	li	a0,800
.L119:
	call	score_add
.L91:
	lw	s0,56(sp)
	lw	ra,60(sp)
	lw	s1,52(sp)
	lw	s2,48(sp)
	lw	s3,44(sp)
	lw	s4,40(sp)
	lw	s5,36(sp)
	lw	s6,32(sp)
	lw	s7,28(sp)
	lw	s8,24(sp)
	addi	sp,sp,64
	tail	spawn_piece
	.size	advance_game, .-advance_game
	.section	.text.startup.main,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-64
	sw	ra,60(sp)
	li	a5,1073750016
	li	a4,1
	sw	s0,56(sp)
	sw	s4,40(sp)
	sw	s1,52(sp)
	sw	s2,48(sp)
	sw	s3,44(sp)
	sw	s5,36(sp)
	sw	s6,32(sp)
	sw	s7,28(sp)
	sw	s8,24(sp)
	sw	a4,12(a5)
	li	a0,27
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
	lui	s4,%hi(gBoard)
	call	uart_putc
	addi	s4,s4,%lo(gBoard)
	call	game_reset
	lui	s0,%hi(gPieceY)
.L146:
	li	a5,1073741824
	lw	a5,4(a5)
	lui	s3,%hi(gGameOver)
	andi	a5,a5,1
	beq	a5,zero,.L121
	li	a5,1073741824
	lw	a4,12(a5)
	li	a3,82
	andi	a5,a4,223
	bne	a5,a3,.L122
	call	game_reset
.L121:
	lw	a5,%lo(gGameOver)(s3)
	beq	a5,zero,.L126
.L124:
	lui	a5,%hi(gNeedRedraw)
	lw	a5,%lo(gNeedRedraw)(a5)
	bne	a5,zero,.L135
.L136:
	li	a5,49152
	sw	zero,12(sp)
	addi	a5,a5,847
.L144:
	lw	a4,12(sp)
	bgtu	a4,a5,.L146
	lw	a4,12(sp)
	addi	a4,a4,1
	sw	a4,12(sp)
	j	.L144
.L122:
	lw	a3,%lo(gGameOver)(s3)
	bne	a3,zero,.L124
	li	a3,65
	bne	a5,a3,.L125
	lui	s2,%hi(gPieceX)
	lw	s1,%lo(gPieceX)(s2)
	addi	s1,s1,-1
.L182:
	lui	a5,%hi(gPieceRot)
	lw	a3,%lo(gPieceRot)(a5)
	lui	a5,%hi(gPieceType)
	lw	a2,%lo(gPieceType)(a5)
	lw	a1,%lo(gPieceY)(s0)
	mv	a0,s1
	call	piece_fits
	beq	a0,zero,.L126
	sw	s1,%lo(gPieceX)(s2)
.L178:
	lui	a5,%hi(gNeedRedraw)
	li	a4,1
	sw	a4,%lo(gNeedRedraw)(a5)
.L126:
	lui	s1,%hi(gGravityCounter)
	lw	a5,%lo(gGravityCounter)(s1)
	bne	a5,zero,.L173
	call	advance_game
	call	gravity_reload
	lui	a5,%hi(gNeedRedraw)
	li	a4,1
	sw	a0,%lo(gGravityCounter)(s1)
	sw	a4,%lo(gNeedRedraw)(a5)
.L135:
	call	term_home
	li	a0,82
	call	uart_putc
	li	a0,86
	call	uart_putc
	li	a0,51
	call	uart_putc
	li	a0,50
	call	uart_putc
	li	a0,73
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,84
	call	uart_putc
	li	a0,69
	call	uart_putc
	li	a0,84
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,73
	call	uart_putc
	li	a0,83
	call	uart_putc
	li	s5,0
	call	term_crlf
	li	s2,0
	call	draw_border
.L141:
	li	a0,124
	call	uart_putc
	li	s1,0
	add	s7,s5,s4
	lui	s8,%hi(gPieceX)
.L140:
	lw	s6,%lo(gGameOver)(s3)
	bne	s6,zero,.L137
	lui	a5,%hi(gPieceRot)
	lw	a3,%lo(gPieceY)(s0)
	lw	a2,%lo(gPieceX)(s8)
	lw	a1,%lo(gPieceRot)(a5)
	lui	a5,%hi(gPieceType)
	lw	a0,%lo(gPieceType)(a5)
	sub	a3,s2,a3
	sub	a2,s1,a2
	call	piece_has_block
	beq	a0,zero,.L137
	li	a0,64
.L176:
	call	uart_putc
	addi	s1,s1,1
	li	a5,10
	bne	s1,a5,.L140
	li	a0,124
	call	uart_putc
	call	term_crlf
	addi	s2,s2,1
	li	a5,16
	add	s5,s5,s1
	bne	s2,a5,.L141
	call	draw_border
	beq	s6,zero,.L142
	li	a0,71
	call	uart_putc
	li	a0,65
	call	uart_putc
	li	a0,77
	call	uart_putc
	li	a0,69
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,79
	call	uart_putc
	li	a0,86
	call	uart_putc
	li	a0,69
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,69
	call	uart_putc
	li	a0,83
	call	uart_putc
	li	a0,69
	call	uart_putc
	li	a0,84
.L177:
	call	uart_putc
	call	term_crlf
	lui	a5,%hi(gNeedRedraw)
	sw	zero,%lo(gNeedRedraw)(a5)
	j	.L136
.L125:
	li	a3,68
	bne	a5,a3,.L127
	lui	s2,%hi(gPieceX)
	lw	s1,%lo(gPieceX)(s2)
	addi	s1,s1,1
	j	.L182
.L127:
	li	a3,87
	bne	a5,a3,.L128
	lui	s1,%hi(gPieceRot)
	lw	a3,%lo(gPieceRot)(s1)
	lui	a5,%hi(gPieceType)
	lw	a2,%lo(gPieceType)(a5)
	lui	a5,%hi(gPieceX)
	addi	a3,a3,1
	lw	a1,%lo(gPieceY)(s0)
	lw	a0,%lo(gPieceX)(a5)
	andi	s2,a3,3
	mv	a3,s2
	call	piece_fits
	beq	a0,zero,.L126
	sw	s2,%lo(gPieceRot)(s1)
	j	.L178
.L128:
	li	a3,83
	bne	a5,a3,.L129
	lui	a5,%hi(gPieceRot)
	lw	s1,%lo(gPieceY)(s0)
	lw	a3,%lo(gPieceRot)(a5)
	lui	a5,%hi(gPieceType)
	lw	a2,%lo(gPieceType)(a5)
	lui	a5,%hi(gPieceX)
	lw	a0,%lo(gPieceX)(a5)
	addi	s1,s1,1
	mv	a1,s1
	call	piece_fits
	bne	a0,zero,.L130
.L180:
	call	advance_game
	j	.L175
.L130:
	sw	s1,%lo(gPieceY)(s0)
.L175:
	call	gravity_reload
	lui	a5,%hi(gGravityCounter)
	sw	a0,%lo(gGravityCounter)(a5)
	li	a4,1
	lui	a5,%hi(gNeedRedraw)
	sw	a4,%lo(gNeedRedraw)(a5)
	j	.L121
.L129:
	andi	a4,a4,255
	li	a5,32
	bne	a4,a5,.L126
	lui	s2,%hi(gPieceY)
	lui	s7,%hi(gPieceRot)
	lui	s6,%hi(gPieceType)
	lui	s5,%hi(gPieceX)
.L132:
	lw	s1,%lo(gPieceY)(s2)
	lw	a3,%lo(gPieceRot)(s7)
	lw	a2,%lo(gPieceType)(s6)
	lw	a0,%lo(gPieceX)(s5)
	addi	s1,s1,1
	mv	a1,s1
	call	piece_fits
	beq	a0,zero,.L180
	li	a0,2
	sw	s1,%lo(gPieceY)(s2)
	call	score_add
	j	.L132
.L173:
	addi	a5,a5,-1
	sw	a5,%lo(gGravityCounter)(s1)
	j	.L124
.L137:
	add	a5,s7,s1
	lbu	a5,0(a5)
	li	a0,35
	bne	a5,zero,.L176
	li	a0,32
	j	.L176
.L142:
	li	a0,65
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,76
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,68
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,87
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,84
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,83
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,68
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,69
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,83
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,80
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,72
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,68
	call	uart_putc
	call	term_crlf
	li	a0,83
	call	uart_putc
	li	a0,67
	call	uart_putc
	li	a0,79
	call	uart_putc
	li	a0,82
	call	uart_putc
	li	a0,69
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,79
	call	uart_putc
	li	a0,78
	call	uart_putc
	li	a0,32
	call	uart_putc
	li	a0,70
	call	uart_putc
	li	a0,78
	call	uart_putc
	li	a0,68
	j	.L177
	.size	main, .-main
	.section	.bss.gGravityCounter,"aw",@nobits
	.align	2
	.type	gGravityCounter, @object
	.size	gGravityCounter, 4
gGravityCounter:
	.zero	4
	.section	.bss.gNeedRedraw,"aw",@nobits
	.align	2
	.type	gNeedRedraw, @object
	.size	gNeedRedraw, 4
gNeedRedraw:
	.zero	4
	.section	.bss.gGameOver,"aw",@nobits
	.align	2
	.type	gGameOver, @object
	.size	gGameOver, 4
gGameOver:
	.zero	4
	.section	.bss.gLines,"aw",@nobits
	.align	2
	.type	gLines, @object
	.size	gLines, 4
gLines:
	.zero	4
	.section	.bss.gScore,"aw",@nobits
	.align	2
	.type	gScore, @object
	.size	gScore, 4
gScore:
	.zero	4
	.section	.bss.gPieceRot,"aw",@nobits
	.align	2
	.type	gPieceRot, @object
	.size	gPieceRot, 4
gPieceRot:
	.zero	4
	.section	.bss.gPieceType,"aw",@nobits
	.align	2
	.type	gPieceType, @object
	.size	gPieceType, 4
gPieceType:
	.zero	4
	.section	.bss.gPieceY,"aw",@nobits
	.align	2
	.type	gPieceY, @object
	.size	gPieceY, 4
gPieceY:
	.zero	4
	.section	.bss.gPieceX,"aw",@nobits
	.align	2
	.type	gPieceX, @object
	.size	gPieceX, 4
gPieceX:
	.zero	4
	.section	.bss.gRngState,"aw",@nobits
	.align	2
	.type	gRngState, @object
	.size	gRngState, 4
gRngState:
	.zero	4
	.section	.bss.gBoard,"aw",@nobits
	.align	2
	.type	gBoard, @object
	.size	gBoard, 160
gBoard:
	.zero	160
	.ident	"GCC: (xPack GNU RISC-V Embedded GCC x86_64) 15.2.0"
	.section	.note.GNU-stack,"",@progbits
