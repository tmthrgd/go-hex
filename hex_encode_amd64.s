// Copyright 2016 Tom Thorogood. All rights reserved.
// Use of this source code is governed by a
// Modified BSD License license that can be found in
// the LICENSE file.
//
// Copyright 2005-2016, Wojciech Muła. All rights reserved.
// Use of this source code is governed by a
// Simplified BSD License license that can be found in
// the LICENSE file.

// +build amd64,!gccgo,!appengine

#include "textflag.h"

DATA encodeMask<>+0x00(SB)/8, $0x0f0f0f0f0f0f0f0f
DATA encodeMask<>+0x08(SB)/8, $0x0f0f0f0f0f0f0f0f
GLOBL encodeMask<>(SB), RODATA, $16

#define VPAND_SSE(x0, x1, x2) MOVOU x1, x2; PAND x0, x2
#define VPAND_AVX(x0, x1, x2) VPAND x0, x1, x2

#define VPUNPCKHBW_SSE(x0, x1, x2) MOVOU x1, x2; PUNPCKHBW x0, x2
#define VPUNPCKHBW_AVX(x0, x1, x2) \
	/* VPUNPCKHBW X1, X0, X2 */ \
	BYTE $0xc5; BYTE $0xf9; BYTE $0x68; BYTE $0xd1

#define VPSHUFB_SSE(x0, x1, x2) MOVOU x1, x2; PSHUFB x0, x2
#define VPSHUFB_AVX_X0_X15_X1(x0, x1, x2) \
	/* VPSHUFB X0, X15, X1 */ \
	BYTE $0xc4; BYTE $0xe2; BYTE $0x01; BYTE $0x00; BYTE $0xc8
#define VPSHUFB_AVX_X2_X15_X3(x0, x1, x2) \
	/* VPSHUFB X2, X15, X3 */ \
	BYTE $0xc4; BYTE $0xe2; BYTE $0x01; BYTE $0x00; BYTE $0xda

#define CONVERT(vpand, vpunpckhbw, vpshufb_x0_x15_x1, vpshufb_x2_x15_x3) \
	vpand(encodeMask<>(SB), X0, X1) \
	\
	PSRLW $4, X0 \
	PAND encodeMask<>(SB), X0 \
	\
	vpunpckhbw(X1, X0, X2) \
	PUNPCKLBW X1, X0 \
	\
	vpshufb_x0_x15_x1(X0, X15, X1) \
	vpshufb_x2_x15_x3(X2, X15, X3)

#define BIGLOOP(name, vpand, vpunpckhbw, vpshufb_x0_x15_x1, vpshufb_x2_x15_x3) \
name: \
	MOVOU -16(SI)(BX*1), X0 \
	\
	CONVERT(vpand, vpunpckhbw, vpshufb_x0_x15_x1, vpshufb_x2_x15_x3) \
	\
	MOVOU X3, -16(DI)(BX*2) \
	MOVOU X1, -32(DI)(BX*2) \
	\
	SUBQ $16, BX \
	JZ ret \
	\
	CMPQ BX, $16 \
	JAE name

// func encodeASM(*byte, *byte, uint64, *byte)
TEXT ·encodeASM(SB),NOSPLIT,$0
	MOVQ dst+0(FP), DI
	MOVQ src+8(FP), SI
	MOVQ len+16(FP), BX
	MOVQ alpha+24(FP), DX

	MOVOU (DX), X15

	CMPQ BX, $16
	JB tail

	CMPB runtime·support_avx(SB), $1
	JNE bigloop_sse

BIGLOOP(bigloop_avx, VPAND_AVX, VPUNPCKHBW_AVX, VPSHUFB_AVX_X0_X15_X1, VPSHUFB_AVX_X2_X15_X3)

tail:
	CMPQ BX, $2
	JB tail_in_1
	JEQ tail_in_2

	CMPQ BX, $4
	JB tail_in_3
	JEQ tail_in_4

	CMPQ BX, $6
	JB tail_in_5
	JEQ tail_in_6

	CMPQ BX, $8
	JB tail_in_7

tail_in_8:
	MOVQ 0(SI), X0
	JMP tail_conv
tail_in_7:
	PINSRB $6, 6(SI), X0
tail_in_6:
	PINSRB $5, 5(SI), X0
tail_in_5:
	PINSRB $4, 4(SI), X0
tail_in_4:
	PINSRD $0, 0(SI), X0
	JMP tail_conv
tail_in_3:
	PINSRB $2, 2(SI), X0
tail_in_2:
	PINSRB $1, 1(SI), X0
tail_in_1:
	PINSRB $0, 0(SI), X0

tail_conv:
	CONVERT(VPAND_SSE, VPUNPCKHBW_SSE, VPSHUFB_SSE, VPSHUFB_SSE)

	CMPQ BX, $2
	JB tail_out_1
	JEQ tail_out_2

	CMPQ BX, $4
	JB tail_out_3
	JEQ tail_out_4

	CMPQ BX, $6
	JB tail_out_5
	JEQ tail_out_6

	CMPQ BX, $8
	JB tail_out_7

tail_out_8:
	MOVOU X1, 0(DI)

	SUBQ $8, BX
	JZ ret

	ADDQ $8, SI
	ADDQ $16, DI

	JMP tail
tail_out_7:
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x4f; BYTE $0x0c; BYTE $0x06 // PEXTRW $6, X1, 12(DI)
tail_out_6:
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x4f; BYTE $0x0a; BYTE $0x05 // PEXTRW $5, X1, 10(DI)
tail_out_5:
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x4f; BYTE $0x08; BYTE $0x04 // PEXTRW $4, X1, 8(DI)
tail_out_4:
	MOVQ X1, 0(DI)
	RET
tail_out_3:
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x4f; BYTE $0x04; BYTE $0x02 // PEXTRW $2, X1, 4(DI)
tail_out_2:
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x4f; BYTE $0x02; BYTE $0x01 // PEXTRW $1, X1, 2(DI)
tail_out_1:
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x0f; BYTE $0x00             // PEXTRW $0, X1, 0(DI)

ret:
	RET

BIGLOOP(bigloop_sse, VPAND_SSE, VPUNPCKHBW_SSE, VPSHUFB_SSE, VPSHUFB_SSE)
	JMP tail
