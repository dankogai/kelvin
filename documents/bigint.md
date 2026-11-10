# BigInt: integers of any size, of the prelude

`BigInt` holds an integer of any size, as Python's `int` and JS's `BigInt` do, with Kelvin's operators on it.

## Synopsis

```swift
let factorial(n:i64):BigInt {
    var f = BigInt(1)
    for i in 2...n { f *= i }
    return f
}

let main():int32 {
    let f = factorial(30)
    println(f, " ", f.hex)                         // 265252859812191058636308480000000n +0xd13f6370f96865df5dd54000000n
    let big = 1n << 100                            // 123n, a literal (#508)
    var n = BigInt("123456789012345678901234567890")
    println(big, " ", n % 97, " ", -n / 7, " ", n > big)   // 1267650600228229401496703205376n 52n -17636684144620811271604938270n false
    println(BigInt(-7) / 2, " ", BigInt(-7) % 2, " ", BigInt(-6) & 0xff, " ", ~BigInt(0))   // -3n -1n 250n -1n
    return 0
}
```

## Description

`BigInt` (#507) is the prelude's, as `RegExp` is (#504): a program that
names it has it, with no import.

- **It is an owner,** as a `String` is: a variable holds it and its
  block frees it.
  - `=` does not copy one; `b.copy()` does, and passing one by value
    moves it (O5, [ownership.md](ownership.md)).
  - An operator is lent its operands (#501), so `a * a + b` leaves `a`
    and `b`.
- **Making one:**
  - **`123n`** is a literal (#508), as JS writes one: an integer's digits
    and an `n`, decimal, `0x` hex or `0b` binary, `0xffn`, `0b101n`.
    - It is `BigInt("123", 10)`, so a literal of any length is whole:
      `123456789012345678901234567890n`.
    - A leading `0`, C's octal, is an error, as in JS: `017n`.
    - `-5n` is `-` of `5n`.
  - `BigInt(n)` of any integer, an `i64` or a `u64`.
  - `BigInt(text)` of a `cstr` or a `String` by reference, `BigInt(&s)`,
    and `BigInt(text, base)` with a base from 2 to 36.
  - The text is read as `i64(s)` reads it, `strtol`'s way: leading
    spaces, a sign, a `0x` before base 16's digits, `0o` before 8's and
    `0b` before 2's, then the longest run of digits; `0` where there are
    none, `BigInt("12x")` is 12, and `BigInt("123n")` 123n.
- **Operators,** with C's precedence:
  - `+ - * / %`, with `/` truncated toward zero and `%` of the
    dividend's sign, as Kelvin's integers are: `BigInt(-7) / 2` is -3,
    `BigInt(-7) % 2` is -1.
  - `== != < <= > >=`.
  - `& | ~` and `~` of one, as if in two's complement of any width:
    `BigInt(-6) & 0xff` is 250, `~BigInt(0)` is -1.
  - `<<` and `>>` by an `i64`; `>>` keeps the sign, rounding down, and a
    negative count shifts the other way.
  - Unary `-`; and `x op= y`, which is `x = x op y`.
  - An `i64` may be on either side: `b + 1`, `1 + b`, `b == 0`,
    `b & 0xff`.
- **Division by zero** ends the program, as a failed check does (#174):
  `kelvin: division of a BigInt by zero`, status 1.
- **Text** is the literal, `123n`, `-5n`, `0n` (#509), so that it reads
  back as the value: `BigInt($`${b}`)` is `b`, the reader stopping at
  the `n`.
  - `print`, `println`, `$`${b}``, `.cstr` and a value that holds one,
    `[1n, -2n]`, all show it, by `b.string` (#506); `` `${b}` `` and
    `.cstr` cut it at 256 bytes, as a String value's.
  - `b.hex`, `b.oct` and `b.bin` are the literal in base 16, 8 and 2,
    signed as Kelvin's signed integers are, `+0xffn`, `-0o17n`,
    `+0b101n`; `BigInt(b.hex, 16)` reads it back, as `i64(s, 16)` does
    `0x`, and base 8 `0o` and base 2 `0b`.
  - `b.text(base)` is the bare digits in a base from 2 to 36, as JS's
    `b.toString(16)`, its letters lowercase, a `-` before a negative
    one, no prefix and no `n`; another base ends the program.
- **Numbers out:** `b.i64` and `b.u64` are the low 64 bits, as C's
  casts wrap them; `b.f64` is the nearest double, about.
- **Not yet:** `**`, `gcd`, the square root, Karatsuba's multiplication,
  a checked `i64`, and kc, which reads no module written in Kelvin and
  refuses a `123n` literal in words.

## Where it lives

`modules/BigInt.k`, written in Kelvin alone, after the algorithms of
swift-bignum: two's complement in little-endian `u64` limbs, the top bit
repeated to the left, kept as short as it can be; zero is no limbs.

- Multiplication is the schoolbook one, division Knuth's algorithm D,
  both on the magnitudes, with `u128` for two limbs.
- `make` builds its header, `modules/BigInt.kh`, and its object with
  `kelvinc --prelude` (#504); libkelvin holds the object, and a program
  links it only where it uses it.
- kelvinc brings `BigInt.kh` in where a program names `BigInt`; a
  program with a type of its own named `BigInt` keeps it.
- Its helpers are `kv_bi_`, the runtime's names, which a program may not
  write.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| a literal | `123n`, `0xffn`, `0b101n` | a `BigInt` (#508) |
| the type | `BigInt(n)` | of an integer, an `i64` or a `u64` |
| | `BigInt(text)`, `BigInt(text, base)` | of a `cstr` or a `String` by reference, read as `i64(s)` reads it |
| a `BigInt` | `.string` | its literal, `123n`, a String, which print shows (#506, #509) |
| | `.hex`, `.oct`, `.bin` | its literal in base 16, 8 or 2, `+0xffn`, `-0o17n`, `+0b101n` (#509) |
| | `.text(base)` | its bare digits in a base from 2 to 36, a String |
| | `.isZero`, `.isNegative` | bools |
| | `.signum` | -1, 0 or 1, an `i64` |
| | `.abs` | its magnitude, a `BigInt` |
| | `.i64`, `.u64` | its low 64 bits |
| | `.f64` | the nearest double, about |
| | `.copy()` | a new `BigInt` of the same value |
| | `+ - * / %`, `== != < <= > >=`, `& \| ~ << >>`, `-b`, `~b` | with a `BigInt` or an `i64` on the other side; `<<` and `>>` by an `i64` |
