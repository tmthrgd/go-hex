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

DATA decodeValid<>+0x00(SB)/1, $'0'
DATA decodeValid<>+0x01(SB)/1, $'9'
DATA decodeValid<>+0x02(SB)/1, $'a'
DATA decodeValid<>+0x03(SB)/1, $'f'
DATA decodeValid<>+0x04(SB)/1, $'A'
DATA decodeValid<>+0x05(SB)/1, $'F'
GLOBL decodeValid<>(SB), RODATA, $16

DATA decodeZero<>+0x00(SB)/8, $0x3030303030303030 // '0'
DATA decodeZero<>+0x08(SB)/8, $0x3030303030303030 // '0'
GLOBL decodeZero<>(SB), RODATA, $16

DATA decodeBase<>+0x00(SB)/8, $0x2727272727272727 // 'a' - '0' - 10
DATA decodeBase<>+0x08(SB)/8, $0x2727272727272727 // 'a' - '0' - 10
GLOBL decodeBase<>(SB), RODATA, $16

DATA decode96<>+0x00(SB)/8, $0x6060606060606060 // 'a' - 1
DATA decode96<>+0x08(SB)/8, $0x6060606060606060 // 'a' - 1
GLOBL decode96<>(SB), RODATA, $16

DATA decodeToLower<>+0x00(SB)/8, $0x2020202020202020
DATA decodeToLower<>+0x08(SB)/8, $0x2020202020202020
GLOBL decodeToLower<>(SB), RODATA, $16

DATA decodeHigh<>+0x00(SB)/8, $0x0e0c0a0806040200
DATA decodeHigh<>+0x08(SB)/8, $0xffffffffffffffff
GLOBL decodeHigh<>(SB), RODATA, $16

DATA decodeLow<>+0x00(SB)/8, $0x0f0d0b0907050301
DATA decodeLow<>+0x08(SB)/8, $0xffffffffffffffff
GLOBL decodeLow<>(SB), RODATA, $16

#define VPCMPGTB_SSE(x0, x1, x2) MOVOU x1, x2; PCMPGTB x0, x2
#define VPCMPGTB_AVX(x0, x1, x2) \
	BYTE $0xc4; BYTE $0xc1; BYTE $0x71; BYTE $0x64; BYTE $0xd6 // VPCMPGTB X14, X1, X2

#define VPXOR_SSE(x0, x1, x2) MOVOU x1, x2; PXOR x0, x2
#define VPXOR_AVX(x0, x1, x2) VPXOR x0, x1, x2

#define VPSHUFB_SSE(x0, x1, x2) MOVOU x1, x2; PSHUFB x0, x2
#define VPSHUFB_AVX(x0, x1, x2) \
	BYTE $0xc4; BYTE $0xc2; BYTE $0x71; BYTE $0x00; BYTE $0xd5 // VPSHUFB X13, X1, X2

#define CONVERT(vpcmpgtb, vpxor, vpshufb) \
	/* PCMPESTRI $0x34, X1, X15 */ \
	BYTE $0x66; BYTE $0x44; BYTE $0x0f; BYTE $0x3a; BYTE $0x61; BYTE $0xf9; BYTE $0x34 \
	JC invalid \
	\
	POR decodeToLower<>(SB), X1 \
	\
	vpcmpgtb(X14, X1, X2) \
	PAND decodeBase<>(SB), X2 \
	\
	PSUBB decodeZero<>(SB), X1 \
	PSUBB X2, X1 \
	\
	vpshufb(X13, X1, X2) \
	PSHUFB decodeHigh<>(SB), X1 \
	\
	PSLLW $4, X1 \
	POR X2, X1

#define BIGLOOP(name, vpcmpgtb, vpxor, vpshufb) \
name: \
	MOVOU (SI), X1 \
	\
	CONVERT(vpcmpgtb, vpxor, vpshufb) \
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

	MOVQ $6, AX

	MOVOU decodeLow<>(SB), X13
	MOVOU decode96<>(SB), X14
	MOVOU decodeValid<>(SB), X15

	CMPQ BX, $16
	JB loop_preheader

	MOVQ $16, DX

	CMPB runtime·support_avx(SB), $1
	JNE bigloop_sse

BIGLOOP(bigloop_avx, VPCMPGTB_AVX, VPXOR_AVX, VPSHUFB_AVX)

loop_preheader:
	MOVQ $2, DX

loop:
	PINSRW $0, (SI), X1

	CONVERT(VPCMPGTB_SSE, VPXOR_SSE, VPSHUFB_SSE)

	PEXTRB $0, X1, (DI)

	ADDQ $2, SI
	INCQ DI

	SUBQ $2, BX
	JNZ loop

ret:
	MOVB $1, ok+32(FP)
	RET

invalid:
	SUBQ R15, SI
	ADDQ SI, CX
	MOVQ CX, n+24(FP)

	MOVB $0, ok+32(FP)
	RET

BIGLOOP(bigloop_sse, VPCMPGTB_SSE, VPXOR_SSE, VPSHUFB_SSE)
	JMP loop_preheader
