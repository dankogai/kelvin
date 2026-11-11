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
    - a Ruby built with GMP does its big integers by GMP (#519), which
      the Ruby row of the table says, `with GMP 6.3.0` or `without GMP`;
  - Kelvin `.pow(e, m)`, `.gcd(b)` and `.isqrt()`;
  - JS, which has none of the three, the textbook's: Euclid's, Newton's
    and square and multiply.
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
| Kelvin | kelvinc 0.2.0, with #518 |
| GMP | GMP 6.3.0 (MacPorts) |
| Ruby | ruby 4.0.8 +PRISM (MacPorts), without GMP |
| Python | Python 3.14.9 (MacPorts) |
| Node | Node v24.21.0 (MacPorts) |
| Date | 2026-11-11 |

| Benchmark | Kelvin | GMP | Ruby | Python | Node |
|:--|--:|--:|--:|--:|--:|
| sum 1...100_000 (100k small ops) | 606.87 µs (1.7×) | **349.50 µs** | 3.52 ms (10.1×) | 2.38 ms (6.8×) | 4.95 ms (14.2×) |
| fib(10_000) (2,090 digits) | 569.50 µs (2.5×) | **227.25 µs** | 1.93 ms (8.5×) | 1.44 ms (6.3×) | 709.96 µs (3.1×) |
| factorial(1_000) (2,568 digits) | 53.38 µs (1.3×) | **41.50 µs** | 309.00 µs (7.4×) | 262.33 µs (6.3×) | 107.00 µs (2.6×) |
| 2 ** 100_000 (30,103 digits) | 1.29 µs (6.2×) | **0.21 µs** | 10.00 µs (48.1×) | 264.17 µs (1270.0×) | 0.38 µs (1.8×) |
| 10k-digit × 10k-digit, 100 times | 15.70 ms (4.1×) | **3.84 ms** | 31.26 ms (8.1×) | 53.73 ms (14.0×) | 7.84 ms (2.0×) |
| 20k-digit ÷ 10k-digit, 100 times | 37.34 ms (3.6×) | **10.45 ms** | 149.99 ms (14.4×) | 108.85 ms (10.4×) | 18.85 ms (1.8×) |
| 2060-bit modular power | 9.99 ms (4.2×) | **2.38 ms** | 34.71 ms (14.6×) | 33.47 ms (14.0×) | 12.73 ms (5.3×) |
| gcd of two 1,000-digit numbers, 10 times | **133.75 µs** | 157.25 µs (1.2×) | 3.35 ms (25.1×) | 182.42 µs (1.4×) | 3.92 ms (29.3×) |
| isqrt of a 20k-digit number, 10 times | 3.47 ms (5.1×) | **678.38 µs** | 13.79 ms (20.3×) | 15.37 ms (22.7×) | 29.76 ms (43.9×) |
| 2 ** 100_000 to decimal text | 2.15 ms (4.3×) | **496.67 µs** | 6.00 ms (12.1×) | 5.21 ms (10.5×) | 1.59 ms (3.2×) |
| parse 10,000 decimal digits, 100 times | 10.87 ms (2.4×) | **4.57 ms** | 30.66 ms (6.7×) | 45.82 ms (9.9×) | 9.30 ms (2.0×) |

Kelvin's own column, before and after #518:

| Benchmark | #517 | #518 | Faster |
|:--|--:|--:|--:|
| sum 1...100_000 | 15.83 ms | 606.87 µs | 26× |
| fib(10_000) | 8.15 ms | 569.50 µs | 14× |
| factorial(1_000) | 1.78 ms | 53.38 µs | 33× |
| 2 ** 100_000 | 928.58 µs | 1.29 µs | 720× |
| 10k × 10k, 100 times | 120.82 ms | 15.70 ms | 7.7× |
| 20k ÷ 10k, 100 times | 447.69 ms | 37.34 ms | 12× |
| 2060-bit modular power | 105.74 ms | 9.99 ms | 11× |
| gcd, 10 times | 39.42 ms | 133.75 µs | 295× |
| isqrt, 10 times | 717.97 ms | 3.47 ms | 207× |
| to decimal text | 54.75 ms | 2.15 ms | 25× |
| parse, 100 times | 225.05 ms | 10.87 ms | 21× |

## What the numbers say

- **GMP is the champion,** the fastest in ten rows of eleven, 1.3× to
  6× ahead of Kelvin; gcd alone is Kelvin's, 1.2× ahead of `mpz_gcd`
  on numbers of this size.
- **Kelvin is second to GMP in five rows,** Node in the other five.
- **Kelvin beats Python in every row,** by 1.4× (gcd, against Python's
  Lehmer's) to 200× (`2 ** 100_000`, against Python's squares).
- **It beats Ruby without GMP in every row,** MacPorts' Ruby here; a
  Ruby built with GMP is another matter (#519), below.
- **It beats Node in six rows:** sum, fib, factorial, modular power,
  gcd and isqrt.
  - Node's V8 wins multiplication, division and the text both ways by
    about 2×, and `2 ** 100_000`, a shift in both.
- **Where #517's 30× to 1000× went:**
  - **`-O0`:** the Makefile built BigInt's object, and the prelude's
    and `--lib`'s others, without `-O`; built as the runtime is, with
    `-O -g`, it is 3× to 6× faster by itself.
  - **Allocations:** each limb was appended, `r += t`, each operand
    copied into a magnitude, and `x += y` made a new BigInt each time.
    Now a result is made once at its size, a non-negative operand is
    read in place, and BigInt's own `+=`, `-=` and `*=` change `x` in
    its limbs (#518's `static let +=(a:Self^, b:U)`).
  - **Bounds checks:** the loops index `a.at`, unchecked, not `a[i]`.
  - **Algorithms:**
    - gcd is Lehmer's, not Euclid's whole divisions;
    - isqrt doubles its precision, as Python's `math.isqrt`, not
      Newton's from a power of 2 with a whole division a step;
    - decimal text divides and conquers, not a division by 10^19 for
      each 19 digits;
    - a power of a value with factors of 2 shifts them in at the end;
    - a square takes each product of two limbs once.
- **What is left,** where GMP and V8 are ahead: Toom-Cook and FFT
  multiplication past Karatsuba, a division that multiplies
  (Burnikel-Ziegler), and assembly for the limb loops.

## On GitHub's runners

The Benchmark workflow's first run (#519), of #518's commit, on macOS
(an Apple M1, virtual) and Ubuntu (an Intel Xeon 8370C, gcc 15.2):

- **Their Ruby is built with GMP,** as ruby/setup-ruby's is: its big
  integers are GMP's, with Ruby's own steps around them.
  - It beats Kelvin at multiplication, division, modular power, isqrt,
    and the text both ways, close to GMP itself.
  - On macOS it is even ahead of GMP at division and modular power, by
    5% to 9%, and 2.4× at decimal text.
  - Kelvin beats it at sum, fib, factorial and `2 ** 100_000`, the
    small steps and the power, where Ruby's own work outweighs GMP's.
  - gcd is a tie on macOS, Ruby 151 µs, Kelvin 152, GMP 154; on Ubuntu
    Kelvin is 1.4× behind GMP and 1.3× behind Ruby.
- **Kelvin still beats Python in every row** on both, and Node in six
  rows on macOS and ten on Ubuntu, all but `2 ** 100_000`.
- **GMP, or Ruby with it, is the fastest in every row** but one on
  Ubuntu, where Kelvin's factorial is ahead of GMP's by 2%, within the
  noise.
- Each job's whole table is in the run's summary.

## In CI

- `.github/workflows/benchmark.yml` runs `run.sh` on ubuntu-latest and
  macos-latest, only by hand (Actions, Benchmark, Run workflow), never on
  a push.
  - It installs GMP (apt's `libgmp-dev`, Homebrew's `gmp`), Ruby 4.0,
    Python 3.14 and Node 24.
  - Each job's table goes to the run's summary, and `out/` to an
    artifact.
