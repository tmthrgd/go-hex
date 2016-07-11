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

DATA decodeZero<>+0x00(SB)/8, $0x3030303030303030 // '0'
DATA decodeZero<>+0x08(SB)/8, $0x3030303030303030 // '0'
GLOBL decodeZero<>(SB), RODATA, $16

DATA decodeBase<>+0x00(SB)/8, $0x2727272727272727 // 'a' - '0' - 10
DATA decodeBase<>+0x08(SB)/8, $0x2727272727272727 // 'a' - '0' - 10
GLOBL decodeBase<>(SB), RODATA, $16

DATA decodeToLower<>+0x00(SB)/8, $0x2020202020202020
DATA decodeToLower<>+0x08(SB)/8, $0x2020202020202020
GLOBL decodeToLower<>(SB), RODATA, $16

DATA decodeHigh<>+0x00(SB)/8, $0x0e0c0a0806040200
DATA decodeHigh<>+0x08(SB)/8, $0xffffffffffffffff
GLOBL decodeHigh<>(SB), RODATA, $16

DATA decodeLow<>+0x00(SB)/8, $0x0f0d0b0907050301
DATA decodeLow<>+0x08(SB)/8, $0xffffffffffffffff
GLOBL decodeLow<>(SB), RODATA, $16

DATA decodeValid<>+0x00(SB)/8, $0xb0b0b0b0b0b0b0b0 // '0' ^ 0x80
DATA decodeValid<>+0x08(SB)/8, $0xb0b0b0b0b0b0b0b0 // '0' ^ 0x80
DATA decodeValid<>+0x10(SB)/8, $0xb9b9b9b9b9b9b9b9 // '9' ^ 0x80
DATA decodeValid<>+0x18(SB)/8, $0xb9b9b9b9b9b9b9b9 // '9' ^ 0x80
DATA decodeValid<>+0x20(SB)/8, $0xe1e1e1e1e1e1e1e1 // 'a' ^ 0x80
DATA decodeValid<>+0x28(SB)/8, $0xe1e1e1e1e1e1e1e1 // 'a' ^ 0x80
DATA decodeValid<>+0x30(SB)/8, $0xe6e6e6e6e6e6e6e6 // 'f' ^ 0x80
DATA decodeValid<>+0x38(SB)/8, $0xe6e6e6e6e6e6e6e6 // 'f' ^ 0x80
GLOBL decodeValid<>(SB), RODATA, $64

DATA decodeSToUS<>+0x00(SB)/8, $0x8080808080808080
DATA decodeSToUS<>+0x08(SB)/8, $0x8080808080808080
GLOBL decodeSToUS<>(SB), RODATA, $16

#define VPXOR_SSE(x0, x1, x2) MOVOU x1, x2; PXOR x0, x2
#define VPXOR_AVX(x0, x1, x2) VPXOR x0, x1, x2

#define VPCMPGTB_SSE(x0, x1, x2) MOVOU x1, x2; PCMPGTB x0, x2
#define VPCMPGTB_AVX_X0_X13_X2(x0, x1, x2) \
	/* VPCMPGTB X0, X13, X2 */ \
	BYTE $0xc5; BYTE $0x91; BYTE $0x64; BYTE $0xd0
#define VPCMPGTB_AVX_X3_X14_X5(x0, x1, x2) \
	/* VPCMPGTB X3, X14, X5 */ \
	BYTE $0xc5; BYTE $0x89; BYTE $0x64; BYTE $0xeb

#define VPSHUFB_SSE(x0, x1, x2) MOVOU x1, x2; PSHUFB x0, x2
#define VPSHUFB_AVX(x0, x1, x2) \
	/* VPSHUFB X15, X1, X2 */ \
	BYTE $0xc4; BYTE $0xc2; BYTE $0x71; BYTE $0x00; BYTE $0xd7

#define CONVERT(vpxor, vpcmpgtb_x0_x13_x2, vpcmpgtb_x3_x14_x5, vpshufb) \
	vpxor(decodeSToUS<>(SB), X1, X0) \
	\
	POR decodeToLower<>(SB), X1 \
	\
	vpxor(decodeSToUS<>(SB), X1, X3) \
	\
	vpcmpgtb_x0_x13_x2(X0, X13, X2) \
	PCMPGTB decodeValid<>+0x10(SB), X0 \
	vpcmpgtb_x3_x14_x5(X3, X14, X5) \
	PCMPGTB decodeValid<>+0x30(SB), X3 \
	\
	PAND X5, X0 \
	POR X3, X2 \
	POR X0, X2 \
	\
	PMOVMSKB X2, AX \
	\
	TESTW AX, DX \
	JNZ invalid \
	\
	PSUBB decodeZero<>(SB), X1 \
	\
	PANDN decodeBase<>(SB), X5 \
	PSUBB X5, X1 \
	\
	vpshufb(X15, X1, X2) \
	PSHUFB decodeHigh<>(SB), X1 \
	\
	PSLLW $4, X1 \
	POR X2, X1

#define BIGLOOP(name, vpxor, vpcmpgtb_x0_x13_x2, vpcmpgtb_x3_x14_x5, vpshufb) \
name: \
	MOVOU (SI), X1 \
	\
	CONVERT(vpxor, vpcmpgtb_x0_x13_x2, vpcmpgtb_x3_x14_x5, vpshufb) \
	\
	MOVQ X1, (DI) \
	\
	SUBQ $16, BX \
	JZ ret \
	\
	ADDQ $16, SI \
	ADDQ $8, DI \
	\
	CMPQ BX, $16 \
	JAE name

// func decodeASM(*byte, *byte, uint64) (n uint64, ok bool)
TEXT ·decodeASM(SB),NOSPLIT,$0
	MOVQ dst+0(FP), DI
	MOVQ src+8(FP), SI
	MOVQ len+16(FP), BX

	MOVQ SI, R15

	MOVW $0xffff, DX

	MOVOU decodeValid<>+0x00(SB), X13
	MOVOU decodeValid<>+0x20(SB), X14
	MOVOU decodeLow<>(SB), X15

	CMPQ BX, $16
	JB tail

	CMPB runtime·support_avx(SB), $1
	JNE bigloop_sse

BIGLOOP(bigloop_avx, VPXOR_AVX, VPCMPGTB_AVX_X0_X13_X2, VPCMPGTB_AVX_X3_X14_X5, VPSHUFB_AVX)

tail:
	MOVQ $16, CX
	SUBQ BX, CX
	SHRW CX, DX

	CMPQ BX, $4
	JB tail_in_2
	JEQ tail_in_4

	CMPQ BX, $8
	JB tail_in_6
	JEQ tail_in_8

	CMPQ BX, $12
	JB tail_in_10
	JEQ tail_in_12

tail_in_14:
	PINSRW $6, 12(SI), X1
tail_in_12:
	PINSRW $5, 10(SI), X1
tail_in_10:
	PINSRW $4, 8(SI), X1
tail_in_8:
	PINSRW $3, 6(SI), X1
tail_in_6:
	PINSRW $2, 4(SI), X1
tail_in_4:
	PINSRW $1, 2(SI), X1
tail_in_2:
	PINSRW $0, 0(SI), X1

	CONVERT(VPXOR_SSE, VPCMPGTB_SSE, VPCMPGTB_SSE, VPSHUFB_SSE)

	CMPQ BX, $4
	JB tail_out_2
	JEQ tail_out_4

	CMPQ BX, $8
	JB tail_out_6
	JEQ tail_out_8

	CMPQ BX, $12
	JB tail_out_10
	JEQ tail_out_12

tail_out_14:
	PEXTRB $6, X1, 6(DI)
tail_out_12:
	PEXTRB $5, X1, 5(DI)
tail_out_10:
	PEXTRB $4, X1, 4(DI)
tail_out_8:
	PEXTRB $3, X1, 3(DI)
tail_out_6:
	PEXTRB $2, X1, 2(DI)
tail_out_4:
	PEXTRB $1, X1, 1(DI)
tail_out_2:
	PEXTRB $0, X1, 0(DI)

ret:
	MOVB $1, ok+32(FP)
	RET

invalid:
	BSFW AX, AX

	SUBQ R15, SI
	ADDQ SI, AX

	MOVQ AX, n+24(FP)
	MOVB $0, ok+32(FP)
	RET

BIGLOOP(bigloop_sse, VPXOR_SSE, VPCMPGTB_SSE, VPCMPGTB_SSE, VPSHUFB_SSE)
	JMP tail
