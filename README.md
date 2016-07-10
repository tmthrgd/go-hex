# go-hex

[![GoDoc](https://godoc.org/github.com/tmthrgd/go-hex?status.svg)](https://godoc.org/github.com/tmthrgd/go-hex)
[![Build Status](https://travis-ci.org/tmthrgd/go-hex.svg?branch=master)](https://travis-ci.org/tmthrgd/go-hex)

An efficient hexadecimal implementation for Golang.

go-hex provides hex encoding and decoding using SSE/AVX instructions on x86-64.

## Download

```
go get github.com/tmthrgd/go-hex
```

## Benchmark

go-hex:
```
BenchmarkEncode_32-8     	100000000	        15.1 ns/op	2118.93 MB/s
BenchmarkEncode_128-8    	50000000	        26.9 ns/op	4753.35 MB/s
BenchmarkEncode_1k-8     	10000000	       124 ns/op	8195.22 MB/s
BenchmarkEncode_16k-8    	 1000000	      1751 ns/op	9352.53 MB/s
BenchmarkEncode_128k-8   	  100000	     15117 ns/op	8669.98 MB/s
BenchmarkEncode_1M-8     	   10000	    130449 ns/op	8038.18 MB/s
BenchmarkEncode_16M-8    	     500	   3599434 ns/op	4661.07 MB/s
BenchmarkEncode_128M-8   	      50	  28384059 ns/op	4728.63 MB/s
BenchmarkDecode_32-8     	100000000	        12.5 ns/op	2565.07 MB/s
BenchmarkDecode_128-8    	50000000	        30.5 ns/op	4196.22 MB/s
BenchmarkDecode_1k-8     	10000000	       197 ns/op	5189.36 MB/s
BenchmarkDecode_16k-8    	  500000	      3077 ns/op	5323.19 MB/s
BenchmarkDecode_128k-8   	   50000	     24383 ns/op	5375.39 MB/s
BenchmarkDecode_1M-8     	   10000	    194553 ns/op	5389.66 MB/s
BenchmarkDecode_16M-8    	     500	   3475647 ns/op	4827.08 MB/s
BenchmarkDecode_128M-8   	      50	  28513252 ns/op	4707.21 MB/s
```

[encoding/hex](https://golang.org/pkg/encoding/hex/):
```
BenchmarkRefEncode_32-8  	20000000	        72.9 ns/op	 439.14 MB/s
BenchmarkRefEncode_128-8 	 5000000	       289 ns/op	 441.54 MB/s
BenchmarkRefEncode_1k-8  	 1000000	      2268 ns/op	 451.49 MB/s
BenchmarkRefEncode_16k-8 	   30000	     39110 ns/op	 418.91 MB/s
BenchmarkRefEncode_128k-8	    5000	    291260 ns/op	 450.02 MB/s
BenchmarkRefEncode_1M-8  	    1000	   2277578 ns/op	 460.39 MB/s
BenchmarkRefEncode_16M-8 	      30	  37087543 ns/op	 452.37 MB/s
BenchmarkRefEncode_128M-8	       5	 293611713 ns/op	 457.13 MB/s
BenchmarkRefDecode_32-8  	10000000	       128 ns/op	 248.44 MB/s
BenchmarkRefDecode_128-8 	 3000000	       481 ns/op	 265.95 MB/s
BenchmarkRefDecode_1k-8  	  300000	      4172 ns/op	 245.43 MB/s
BenchmarkRefDecode_16k-8 	   10000	    111989 ns/op	 146.30 MB/s
BenchmarkRefDecode_128k-8	    2000	    909077 ns/op	 144.18 MB/s
BenchmarkRefDecode_1M-8  	     200	   7275779 ns/op	 144.12 MB/s
BenchmarkRefDecode_16M-8 	      10	 116574839 ns/op	 143.92 MB/s
BenchmarkRefDecode_128M-8	       2	 933871637 ns/op	 143.72 MB/s
```

## License

Unless otherwise noted, the go-hex source files are distributed under the Modified BSD License
found in the LICENSE file.
