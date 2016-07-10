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
GLOBL encodeMask<>(SB), RODATA, $16

#define VPAND_SSE(x0, x1, x2) MOVOU x1, x2; PAND x0, x2
#define VPAND_AVX(x0, x1, x2) VPAND x0, x1, x2

#define VPSHUFB_SSE(x0, x1, x2) MOVOU x1, x2; PSHUFB x0, x2
#define VPSHUFB_AVX(x0, x1, x2) \
	BYTE $0xc4; BYTE $0xe2; BYTE $0x01; BYTE $0x00; BYTE $0xc8 // VPSHUFB X0, X15, X1

#define CONVERT(vpand, vpshufb) \
	vpand(encodeMask<>(SB), X0, X1) \
	\
	PSRLW $4, X0 \
	PAND encodeMask<>(SB), X0 \
	\
	PUNPCKLBW X1, X0 \
	\
	vpshufb(X0, X15, X1)

#define BIGLOOP(name, vpand, vpshufb) \
name: \
	MOVQ -8(SI)(BX*1), X0 \
	\
	CONVERT(vpand, vpshufb) \
	\
	MOVOU X1, -16(DI)(BX*2) \
	\
	SUBQ $8, BX \
	JZ ret \
	\
	CMPQ BX, $8 \
	JAE name

// func encodeASM(*byte, *byte, uint64, *byte)
TEXT ·encodeASM(SB),NOSPLIT,$0
	MOVQ dst+0(FP), DI
	MOVQ src+8(FP), SI
	MOVQ len+16(FP), BX
	MOVQ alpha+24(FP), DX

	MOVOU (DX), X15

	CMPQ BX, $8
	JB tail

	CMPB runtime·support_avx(SB), $1
	JNE bigloop_sse

BIGLOOP(bigloop_avx, VPAND_AVX, VPSHUFB_AVX)

tail:
	CMPQ	BX, $2
	JBE	tail_in_1or2

	CMPQ	BX, $4
	JBE	tail_in_3or4

tail_in_5through7:
	MOVL 0(SI), X0
	PINSRD $1, -4(SI)(BX*1), X0
	JMP tail_conv

tail_in_3or4:
	PINSRW $0, 0(SI), X0
	PINSRW $1, -2(SI)(BX*1), X0
	JMP tail_conv

tail_in_1or2:
	PINSRB $0, 0(SI), X0
	PINSRB $1, -1(SI)(BX*1), X0

tail_conv:
	CONVERT(VPAND_SSE, VPSHUFB_SSE)

tail_out:
	CMPQ	BX, $2
	JBE	tail_out_1or2

	CMPQ	BX, $4
	JBE	tail_out_3or4

tail_out_5through7:
	PEXTRQ $1, X1, -8(DI)(BX*2)
	MOVQ X1, 0(DI)
	RET

tail_out_3or4:
	PEXTRD $1, X1, -4(DI)(BX*2)
	MOVL X1, 0(DI)
	RET

tail_out_1or2:
	// PEXTRW $1, X1, -2(DI)(BX*2)
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x4c; BYTE $0x5f; BYTE $0xfe; BYTE $0x01
	// PEXTRW $0, X1, 0(DI)
	BYTE $0x66; BYTE $0x0f; BYTE $0x3a; BYTE $0x15; BYTE $0x0f; BYTE $0x00

ret:
	RET

BIGLOOP(bigloop_sse, VPAND_SSE, VPSHUFB_SSE)
	JMP tail
