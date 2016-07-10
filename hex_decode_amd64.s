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

DATA decodeValid<>+0x00(SB)/8, $0xafafafafafafafaf // ('0' - 1) ^ 0x80
DATA decodeValid<>+0x08(SB)/8, $0xafafafafafafafaf // ('0' - 1) ^ 0x80
DATA decodeValid<>+0x10(SB)/8, $0xb9b9b9b9b9b9b9b9 // '9' ^ 0x80
DATA decodeValid<>+0x18(SB)/8, $0xb9b9b9b9b9b9b9b9 // '9' ^ 0x80
DATA decodeValid<>+0x20(SB)/8, $0xe0e0e0e0e0e0e0e0 // ('a' - 1) ^ 0x80
DATA decodeValid<>+0x28(SB)/8, $0xe0e0e0e0e0e0e0e0 // ('a' - 1) ^ 0x80
DATA decodeValid<>+0x30(SB)/8, $0xe6e6e6e6e6e6e6e6 // 'f' ^ 0x80
DATA decodeValid<>+0x38(SB)/8, $0xe6e6e6e6e6e6e6e6 // 'f' ^ 0x80
GLOBL decodeValid<>(SB), RODATA, $64

DATA decodeSToUS<>+0x00(SB)/8, $0x8080808080808080
DATA decodeSToUS<>+0x08(SB)/8, $0x8080808080808080
GLOBL decodeSToUS<>(SB), RODATA, $16

#define VPXOR_SSE(x0, x1, x2) MOVOU x1, x2; PXOR x0, x2
#define VPXOR_AVX(x0, x1, x2) VPXOR x0, x1, x2

#define VPCMPGTB_SSE(x0, x1, x2) MOVOU x1, x2; PCMPGTB x0, x2
#define VPCMPGTB_AVX_0x10_R15_X3_X4(x0, x1, x2) \
	/* VPCMPGTB 0x10(R15), X3, X4 */ \
	BYTE $0xc4; BYTE $0xc1; BYTE $0x61; BYTE $0x64; BYTE $0x67; BYTE $0x10
#define VPCMPGTB_AVX_0x20_R15_X3_X5(x0, x1, x2) \
	/* VPCMPGTB 0x20(R15), X3, X5 */ \
	BYTE $0xc4; BYTE $0xc1; BYTE $0x61; BYTE $0x64; BYTE $0x6f; BYTE $0x20

#define VPANDN_SSE(x0, x1, x2) MOVOU x1, x2; PANDN x0, x2
#define VPANDN_AVX(x0, x1, x2) \
	/* VPANDN X4, X5, X7 */ \
	BYTE $0xc5; BYTE $0xd1; BYTE $0xdf; BYTE $0xfc

#define VPSHUFB_SSE(x0, x1, x2) MOVOU x1, x2; PSHUFB x0, x2
#define VPSHUFB_AVX(x0, x1, x2) \
	/* VPSHUFB X14, X1, X2 */ \
	BYTE $0xc4; BYTE $0xc2; BYTE $0x71; BYTE $0x00; BYTE $0xd6

#define CONVERT(vpxor, vpcmpgtb_0x10_r15_x3_x4, vpcmpgtb_0x20_r15_x3_x5, vpandn, vpshufb) \
	vpxor(decodeSToUS<>(SB), X1, X2) \
	\
	POR decodeToLower<>(SB), X1 \
	\
	vpxor(decodeSToUS<>(SB), X1, X3) \
	\
	PCMPGTB 0x00(R15), X2 \
	vpcmpgtb_0x10_r15_x3_x4(0x10(R15), X3, X4) \
	vpcmpgtb_0x20_r15_x3_x5(0x20(R15), X3, X5) \
	PCMPGTB 0x30(R15), X3 \
	\
	PXOR X13, X2 \
	vpandn(X4, X5, X7) \
	\
	POR X7, X2 \
	POR X3, X2 \
	\
	PMOVMSKB X2, AX \
	\
	TESTW AX, DX \
	JNZ invalid \
	\
	PSUBB decodeZero<>(SB), X1 \
	\
	PAND decodeBase<>(SB), X5 \
	PSUBB X5, X1 \
	\
	vpshufb(X14, X1, X2) \
	PSHUFB decodeHigh<>(SB), X1 \
	\
	PSLLW $4, X1 \
	POR X2, X1

#define BIGLOOP(name, vpxor, vpcmpgtb_0x10_r15_x3_x4, vpcmpgtb_0x20_r15_x3_x5, vpandn, vpshufb) \
name: \
	MOVOU (SI), X1 \
	\
	CONVERT(vpxor, vpcmpgtb_0x10_r15_x3_x4, vpcmpgtb_0x20_r15_x3_x5, vpandn, vpshufb) \
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

	MOVQ SI, R14

	MOVQ $6, AX

	PCMPEQL X13, X13
	MOVOU decodeLow<>(SB), X14
	MOVQ $decodeValid<>(SB), R15

	CMPQ BX, $16
	JB loop_preheader

	MOVW $0xffff, DX

	CMPB runtime·support_avx(SB), $1
	JNE bigloop_sse

BIGLOOP(bigloop_avx, VPXOR_AVX, VPCMPGTB_AVX_0x10_R15_X3_X4, VPCMPGTB_AVX_0x20_R15_X3_X5, VPANDN_AVX, VPSHUFB_AVX)

loop_preheader:
	MOVW $0x0003, DX

loop:
	PINSRW $0, (SI), X1

	CONVERT(VPXOR_SSE, VPCMPGTB_SSE, VPCMPGTB_SSE, VPANDN_SSE, VPSHUFB_SSE)

	PEXTRB $0, X1, (DI)

	ADDQ $2, SI
	INCQ DI

	SUBQ $2, BX
	JNZ loop

ret:
	MOVB $1, ok+32(FP)
	RET

invalid:
	BSFW AX, AX

	SUBQ R14, SI
	ADDQ SI, AX

	MOVQ AX, n+24(FP)
	MOVB $0, ok+32(FP)
	RET

BIGLOOP(bigloop_sse, VPXOR_SSE, VPCMPGTB_SSE, VPCMPGTB_SSE, VPANDN_SSE, VPSHUFB_SSE)
	JMP loop_preheader
