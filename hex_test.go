// Copyright 2016 Tom Thorogood. All rights reserved.
// Use of this source code is governed by a
// Modified BSD License license that can be found in
// the LICENSE file.

package hex

import (
	ref "encoding/hex"
	"math/rand"
	"reflect"
	"strings"
	"testing"
	"testing/quick"
)

func testEncode(t *testing.T, enc, ref func([]byte) string, scale float64) {
	if err := quick.CheckEqual(ref, enc, &quick.Config{
		Values: func(args []reflect.Value, rand *rand.Rand) {
			off := rand.Intn(32)

			data := make([]byte, 1+rand.Intn(1024*1024)+off)
			rand.Read(data[off:])
			args[0] = reflect.ValueOf(data[off:])
		},

		MaxCountScale: scale,
	}); err != nil {
		t.Error(err)
	}
}

func TestEncode(t *testing.T) {
	testEncode(t, EncodeToString, ref.EncodeToString, 1.5)
}

func TestEncodeUC(t *testing.T) {
	testEncode(t, EncodeUCToString, func(src []byte) string {
		return strings.ToUpper(ref.EncodeToString(src))
	}, 0.375)
}

func testDecode(t *testing.T, enc func([]byte) string) {
	if err := quick.CheckEqual(func(s string) (string, error) {
		return s, nil
	}, func(s string) (string, error) {
		b, err := DecodeString(s)
		return enc(b), err
	}, &quick.Config{
		Values: func(args []reflect.Value, rand *rand.Rand) {
			off := rand.Intn(32)

			src := make([]byte, 1+rand.Intn(1024*1024)+off)
			rand.Read(src)
			data := enc(src)
			args[0] = reflect.ValueOf(data[2*off:])
		},

		MaxCountScale: 2,
	}); err != nil {
		t.Error(err)
	}
}

func TestDecode(t *testing.T) {
	testDecode(t, EncodeToString)
}

func TestDecodeOfUC(t *testing.T) {
	testDecode(t, EncodeUCToString)
}

func TestDecodeInvalid(t *testing.T) {
	src := make([]byte, 19)
	rand.Read(src)

	dst := make([]byte, EncodedLen(len(src)))
	Encode(dst, src)

	tmp := make([]byte, len(src))

	for pos := 0; pos < len(dst); pos++ {
		old := dst[pos]

		for c := rune(0); c < rune(0x100); c++ {
			dst[pos] = byte(c)

			_, err := Decode(tmp, dst)
			if (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f') {
				if err != nil {
					t.Errorf("unexpected error for %d:%#U: %v", pos, c, err)
				}
			} else if err, ok := err.(InvalidByteError); ok {
				if byte(err) != byte(c) {
					t.Errorf("expected error for %d:%#U, got %v", pos, c, err)
				}
			} else {
				t.Errorf("expected error for %d:%#U, got %v", pos, c, err)
			}
		}

		dst[pos] = old
	}
}

func benchmarkEncode(b *testing.B, l int) {
	src := make([]byte, l)
	rand.Read(src)

	dst := make([]byte, EncodedLen(l))

	b.SetBytes(int64(l))
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		Encode(dst, src)
	}
}

func BenchmarkEncode_32(b *testing.B) {
	benchmarkEncode(b, 32)
}

func BenchmarkEncode_128(b *testing.B) {
	benchmarkEncode(b, 128)
}

func BenchmarkEncode_1k(b *testing.B) {
	benchmarkEncode(b, 1*1024)
}

func BenchmarkEncode_16k(b *testing.B) {
	benchmarkEncode(b, 16*1024)
}

func BenchmarkEncode_128k(b *testing.B) {
	benchmarkEncode(b, 128*1024)
}

func BenchmarkEncode_1M(b *testing.B) {
	benchmarkEncode(b, 1024*1024)
}

func BenchmarkEncode_16M(b *testing.B) {
	benchmarkEncode(b, 16*1024*1024)
}

func BenchmarkEncode_128M(b *testing.B) {
	benchmarkEncode(b, 128*1024*1024)
}

func benchmarkRefEncode(b *testing.B, l int) {
	src := make([]byte, l)
	rand.Read(src)

	dst := make([]byte, ref.EncodedLen(l))

	b.SetBytes(int64(l))
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		ref.Encode(dst, src)
	}
}

func BenchmarkRefEncode_32(b *testing.B) {
	benchmarkRefEncode(b, 32)
}

func BenchmarkRefEncode_128(b *testing.B) {
	benchmarkRefEncode(b, 128)
}

func BenchmarkRefEncode_1k(b *testing.B) {
	benchmarkRefEncode(b, 1*1024)
}

func BenchmarkRefEncode_16k(b *testing.B) {
	benchmarkRefEncode(b, 16*1024)
}

func BenchmarkRefEncode_128k(b *testing.B) {
	benchmarkRefEncode(b, 128*1024)
}

func BenchmarkRefEncode_1M(b *testing.B) {
	benchmarkRefEncode(b, 1024*1024)
}

func BenchmarkRefEncode_16M(b *testing.B) {
	benchmarkRefEncode(b, 16*1024*1024)
}

func BenchmarkRefEncode_128M(b *testing.B) {
	benchmarkRefEncode(b, 128*1024*1024)
}

func benchmarkDecode(b *testing.B, l int) {
	m := DecodedLen(l)

	src := make([]byte, l)
	rand.Read(src[:m])
	Encode(src, src[:m])

	dst := make([]byte, m)

	b.SetBytes(int64(l))
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		Decode(dst, src)
	}
}

func BenchmarkDecode_32(b *testing.B) {
	benchmarkDecode(b, 32)
}

func BenchmarkDecode_128(b *testing.B) {
	benchmarkDecode(b, 128)
}

func BenchmarkDecode_1k(b *testing.B) {
	benchmarkDecode(b, 1*1024)
}

func BenchmarkDecode_16k(b *testing.B) {
	benchmarkDecode(b, 16*1024)
}

func BenchmarkDecode_128k(b *testing.B) {
	benchmarkDecode(b, 128*1024)
}

func BenchmarkDecode_1M(b *testing.B) {
	benchmarkDecode(b, 1024*1024)
}

func BenchmarkDecode_16M(b *testing.B) {
	benchmarkDecode(b, 16*1024*1024)
}

func BenchmarkDecode_128M(b *testing.B) {
	benchmarkDecode(b, 128*1024*1024)
}

func benchmarkRefDecode(b *testing.B, l int) {
	m := ref.DecodedLen(l)

	src := make([]byte, l)
	rand.Read(src[:m])
	Encode(src, src[:m])

	dst := make([]byte, m)

	b.SetBytes(int64(l))
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		ref.Decode(dst, src)
	}
}

func BenchmarkRefDecode_32(b *testing.B) {
	benchmarkRefDecode(b, 32)
}

func BenchmarkRefDecode_128(b *testing.B) {
	benchmarkRefDecode(b, 128)
}

func BenchmarkRefDecode_1k(b *testing.B) {
	benchmarkRefDecode(b, 1*1024)
}

func BenchmarkRefDecode_16k(b *testing.B) {
	benchmarkRefDecode(b, 16*1024)
}

func BenchmarkRefDecode_128k(b *testing.B) {
	benchmarkRefDecode(b, 128*1024)
}

func BenchmarkRefDecode_1M(b *testing.B) {
	benchmarkRefDecode(b, 1024*1024)
}

func BenchmarkRefDecode_16M(b *testing.B) {
	benchmarkRefDecode(b, 16*1024*1024)
}

func BenchmarkRefDecode_128M(b *testing.B) {
	benchmarkRefDecode(b, 128*1024*1024)
}
