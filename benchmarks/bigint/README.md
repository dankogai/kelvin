# benchmarks/bigint: Kelvin's BigInt against GMP, Ruby, Python and Node

How fast is the prelude's `BigInt` (#507), written in Kelvin alone, beside
the integers of any size that other languages give?

## Synopsis

```sh
sh benchmarks/bigint/run.sh
```

- It builds `bench.k` with `kelvinc -O` and `bench.c` with `cc -O2`
  against GMP, runs them and `bench.rb`, `bench.py` and `bench.mjs`, and
  prints a Markdown table.
- Its output goes to `out/` beside it, which git ignores:
  - `out/<name>.tsv`, each one's lines;
  - `out/results.md`, the table.
- It stops with status 1 where two disagree on a result.
- A language it cannot find is left out, with a note.
- Its environment:
  - `KELVINC`, `CC`, `RUBY`, `PYTHON` and `NODE` name the tools;
  - `PYTHON` is the newest `python3.N` on `PATH` where it is not set;
  - `GMP_CFLAGS` and `GMP_LIBS` are GMP's flags, else pkg-config's, else
    those of the first of `/opt/local`, `/opt/homebrew`, `/usr/local` and
    `/usr` with `gmp.h`.

## Description

- **The cases are swift-bigint-gmp's** ([Benchmark.md]): the same 11, the
  same inputs, so the GMP column can be read beside its.
  - Each one runs 3 times, and its best time counts.
  - Each program prints a case's id, its time in seconds and its result
    mod 1000000007; run.sh checks the five agree before it makes the table.
- **Each language uses what it has:**
  - GMP its `mpz_` functions, `mpz_powm`, `mpz_gcd`, `mpz_sqrt`;
  - Python `pow(b, e, m)`, `math.gcd` and `math.isqrt`;
  - Ruby `Integer#pow(e, m)`, `Integer#gcd` and `Integer.sqrt`;
  - Kelvin `.pow(e, m)`, `.gcd(b)` and `.isqrt()`;
  - JS, which has none of the three, Euclid's, Newton's and square and
    multiply, as Kelvin's `BigInt` does them.
- **fib is `a += b; b += a`,** 5,000 times, in every language: the same
  10,000 additions as swift-bigint-gmp's `(a, b) = (b, a + b)`, which
  Kelvin's ownership would write with a move (O3).
- **Times are of a nanosecond clock:**
  - `CLOCK_MONOTONIC_RAW` in Kelvin and C, as macOS's `CLOCK_MONOTONIC`
    counts microseconds;
  - `Process.clock_gettime`, `time.perf_counter` and
    `process.hrtime.bigint` in the others.

[Benchmark.md]: https://github.com/dankogai/swift-bigint-gmp/blob/main/Benchmark.md

## Results

Bold is the fastest of a row; the others have their ratio to it.

| | |
|:--|:--|
| Machine | Apple M1 |
| OS | macOS 26.7.1 |
| C compiler | Apple clang version 21.0.0 (clang-2100.4.1.1) |
| Kelvin | kelvinc 0.2.0 |
| GMP | GMP 6.3.0 (MacPorts) |
| Ruby | ruby 4.0.8 +PRISM (MacPorts, without GMP) |
| Python | Python 3.14.9 (MacPorts) |
| Node | Node v24.21.0 (MacPorts) |
| Date | 2026-11-11 |

| Benchmark | Kelvin | GMP | Ruby | Python | Node |
|:--|--:|--:|--:|--:|--:|
| sum 1...100_000 (100k small ops) | 15.83 ms (28.2×) | **560.50 µs** | 3.45 ms (6.1×) | 2.36 ms (4.2×) | 1.67 ms (3.0×) |
| fib(10_000) (2,090 digits) | 8.15 ms (34.8×) | **234.42 µs** | 1.94 ms (8.3×) | 1.49 ms (6.4×) | 728.04 µs (3.1×) |
| factorial(1_000) (2,568 digits) | 1.78 ms (42.0×) | **42.33 µs** | 284.00 µs (6.7×) | 265.75 µs (6.3×) | 104.04 µs (2.5×) |
| 2 ** 100_000 (30,103 digits) | 928.58 µs (3714.3×) | **0.25 µs** | 7.00 µs (28.0×) | 269.12 µs (1076.5×) | 0.38 µs (1.5×) |
| 10k-digit × 10k-digit, 100 times | 120.82 ms (31.6×) | **3.83 ms** | 31.04 ms (8.1×) | 53.56 ms (14.0×) | 7.77 ms (2.0×) |
| 20k-digit ÷ 10k-digit, 100 times | 447.69 ms (42.4×) | **10.56 ms** | 149.75 ms (14.2×) | 107.81 ms (10.2×) | 18.73 ms (1.8×) |
| 2060-bit modular power | 105.74 ms (44.7×) | **2.36 ms** | 34.42 ms (14.6×) | 33.27 ms (14.1×) | 12.74 ms (5.4×) |
| gcd of two 1,000-digit numbers, 10 times | 39.42 ms (250.7×) | **157.21 µs** | 3.19 ms (20.3×) | 190.38 µs (1.2×) | 3.97 ms (25.2×) |
| isqrt of a 20k-digit number, 10 times | 717.97 ms (1064.7×) | **674.33 µs** | 13.63 ms (20.2×) | 15.23 ms (22.6×) | 29.64 ms (44.0×) |
| 2 ** 100_000 to decimal text | 54.75 ms (109.0×) | **502.29 µs** | 5.92 ms (11.8×) | 5.12 ms (10.2×) | 1.52 ms (3.0×) |
| parse 10,000 decimal digits, 100 times | 225.05 ms (47.9×) | **4.70 ms** | 30.67 ms (6.5×) | 45.34 ms (9.6×) | 9.23 ms (2.0×) |

## What the numbers say

- **GMP is fastest everywhere,** as in swift-bigint-gmp; Node's V8 is
  next in most rows, within 2× of GMP on multiplication, division and
  parsing.
- **Kelvin is last in every row:** on most, 28× to 50× behind GMP and 4×
  to 15× behind Ruby and Python; the rows below go far past that.
- **Small operations** (sum, fib, factorial) cost Kelvin about 160 ns an
  addition, against Python's 24:
  - each makes a new limb array, appended a limb at a time
    (`kv_bi_add`'s `r += t`), and normalizes it;
  - `s += i` makes a `BigInt` of `i` first.
- **Multiplication and division** are the algorithms, not the language:
  - Karatsuba from 40 limbs, as Python's, where Ruby goes on to Toom-3
    and GMP and V8 further;
  - Knuth's algorithm D, quadratic, about 4.5 ms a 20k ÷ 10k division.
- **The worst rows** are those built on division:
  - **isqrt,** 1065×: Newton's from a power of 2, a whole division a
    step, and each step copies (`x = y.copy()`); Python's and GMP's
    `isqrt` grow their precision instead;
  - **gcd,** 251×: Euclid's, about 1,900 divisions, each copying both
    operands; Python and GMP use Lehmer's;
  - **decimal text,** 109×: a division by 10^19 for each 19 digits,
    quadratic, where Python 3.12+ and GMP divide and conquer.
- **`2 ** 100_000`** is squares and multiplies in Kelvin and Python;
  GMP and V8 see a power of 2 and shift.
- **Where to start,** if Kelvin's `BigInt` is to be faster:
  - make a result's limbs once, at their size, not by `+=`;
  - divide and conquer for text, both ways;
  - move instead of `.copy()` in gcd and isqrt, and Lehmer's gcd;
  - a Newton's isqrt that doubles its precision.

## In CI

- `.github/workflows/benchmark.yml` runs `run.sh` on ubuntu-latest and
  macos-latest, only by hand (Actions, Benchmark, Run workflow), never on
  a push.
  - It installs GMP (apt's `libgmp-dev`, Homebrew's `gmp`), Ruby 4.0,
    Python 3.14 and Node 24.
  - Each job's table goes to the run's summary, and `out/` to an
    artifact.
