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

#define BIGLOOP(name, vpand, vpunpckhbw, vpshufb_x0_x15_x1, vpshufb_x2_x15_x3) \
name: \
	MOVOU -16(SI)(BX*1), X0 \
	\
	vpand(encodeMask<>(SB), X0, X1) \
	\
	PSRLW $4, X0 \
	PAND encodeMask<>(SB), X0 \
	\
	vpunpckhbw(X1, X0, X2) \
	PUNPCKLBW X1, X0 \
	\
	vpshufb_x0_x15_x1(X0, X15, X1) \
	vpshufb_x2_x15_x3(X2, X15, X3) \
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
	JB loop

	CMPB runtime·support_avx(SB), $1
	JNE bigloop_sse

BIGLOOP(bigloop_avx, VPAND_AVX, VPUNPCKHBW_AVX, VPSHUFB_AVX_X0_X15_X1, VPSHUFB_AVX_X2_X15_X3)

loop:
	PINSRB $0, -1(SI)(BX*1), X0

	VPAND_SSE(encodeMask<>(SB), X0, X1)

	PSRLW $4, X0
	PAND encodeMask<>(SB), X0

	PUNPCKLBW X1, X0

	VPSHUFB_SSE(X0, X15, X1)

	// PEXTRW $0, X1, -2(DI)(BX*2)
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x4c; BYTE $0x5f; BYTE $0xfe; BYTE $0x00

	SUBQ $1, BX
	JNZ loop

ret:
	RET

BIGLOOP(bigloop_sse, VPAND_SSE, VPUNPCKHBW_SSE, VPSHUFB_SSE, VPSHUFB_SSE)
	JMP loop
