# Integers

Every number in Kelvin says its size. This document has the integer
types, their literals, the two ways to convert any number, how a
number is read from text, powers, `**` and `pow` (#380), `.abs`
(#381) and `.sign` (#382). Floats are in
[floatingpoint.md](floatingpoint.md), and `bool` in [bool.md](bool.md).
The text of a number (`n.cstr`, `n.hex`) is in
[properties.md](properties.md), and `print`'s view of it in
[printing.md](printing.md).

**Where it lives:** the core. Integers are kelvinc's own, written as C's types, with nothing linked. Their text (`.cstr`, `.dec`, `.hex`), printing them, and reading them from text (`i64("42")`) are the prelude's, `libkelvin`, linked without an import.

## Integer types always say their size

Each has a short name, `i64`, and a full one, `int64` (#151); the two
are one type, and either goes wherever a type does.

| Kelvin | C |
|--------|---|
| `i8` `i16` `i32` `i64` | `int8_t` `int16_t` `int32_t` `int64_t` |
| `u8` `u16` `u32` `u64` | `uint8_t` `uint16_t` `uint32_t` `uint64_t` |
| `i128` `u128` | `__int128`, `unsigned __int128` (where the C compiler has them) |
| `int8` ... `int128`, `uint8` ... `uint128` | the same, by their full names (#151) |

C's `char`, `short`, `int`, `long`, `signed` and `unsigned` are errors
that suggest the Kelvin name, as `float`, `double` and `_Bool` are (see
[floatingpoint.md](floatingpoint.md) and [bool.md](bool.md)). As a result:

- There is no plain `char`. Use `u8`, or `i8` for signed bytes; see
  [strings.md](strings.md) for text.
- Each type has a full name too (#151): `int64` is `i64`, `uint8` is
  `u8`, the same type by another name, wherever the short one goes,
  `var n:int64`, `uint8(c)`, `x as int32`; its `.typename` is the short
  one.

Kelvin's built-in types need no header, and neither does `<stdint.h>`,
because the generated C includes it itself.

## Literals

Literals carry no size or type hints. C's suffixes `u`, `l` and `ll`
(`10UL`, `10u`, `10LL`) are errors, as `f` and `L` on a float are (see
[floatingpoint.md](floatingpoint.md)). The type belongs on the
declaration, or on the value as an annotation (`10:u64`):

| C | Kelvin |
|---|--------|
| `unsigned long v = 10UL;` | `var v:u64 = 10` |
| `long long n = 10LL;` | `var n = 10` (or `var n:i64 = 10`) |

Everything else about literals is C's:

- hex `0xff`, octal `017`, binary `0b101`, character constants `'a'`,
  and adjacent strings.
- A literal inside an expression still has C's type, so a bare `1` is
  C's `int` (an `i32`).
- Where C would write `1UL << 40`, Kelvin writes `1:u64 << 40`.

## Conversions (no C casts)

These serve every number, floats and `bool` included.

C's `(T)v` does not exist in Kelvin. There are two ways to convert, and
both mean exactly what the C cast means (`i32(3.9)` is 3, `u8(300)` is 44),
except that a converter of text reads the number in it (#36), while
`s as i64` and `s:i64` stay C's cast:

- **`T(v)`**, a converter, for built-in types: `i32(x)`, `u8(c)`,
  `f64(n) / 2`, `bool(flags & 4)` *(provisional P18)*. Of text, it reads
  the number (#36, below).
- **`v:T`**, a type annotation, means exactly `v as T`: `0xdead:u16`,
  `1:u64 << 40`, `n:size_t`.
  - In the middle of a ternary (`c ? a : b`) and in a `case` label, a
    bare name after `:` is the separator, so annotate with a typedef
    there by using parentheses or `as`.
- **`v as T`**, for any type, including pointers and C typedef names:
  `malloc(n) as i32^`, `p as any^`, `n as size_t`.

### Numbers from text

A converter reads a number from text (#36): `i64("42")`, `f64("1.5")`,
and with a base from 2 to 36 for an integer type, `i32("755", 8)`.

- The property form is the same converter: `"42".i64` is `i64("42")`,
  and `n.u8` is `u8(n)` for a number.
- Text is a string, `cstr`, `u8^`, `i8^`, an array of `u8` or `i8`, the
  text of a property such as `n.hex`, C's `char *`, or a `String` or a
  `Bytes` in a variable, read through its text (#88), as `i64(line)` of
  a line an IO gives.
- Every other value converts as before.
- Where kelvinc cannot see the type, C's `_Generic` makes the choice.

The text is read as C's `strtol` and `strtod` read it *(provisional
P47)*:

| Kelvin | Value | Why |
|--------|-------|-----|
| `i64("  +12")` | 12 | leading spaces and a sign |
| `i64("42abc")` | 42 | the longest number is taken |
| `i64("abc")`, `i64("")` | 0 | no number |
| `i64("0755")` | 755 | base 10 unless one is given |
| `i64("ff", 16)`, `i64("0xff", 16)` | 255 | |
| `i64(n.oct, 8)`, `i64(n.bin, 2)` | `n` | Kelvin's `0o` and `0b` too |
| `i8("300")`, `u8("-1")` | 127, 0 | clamped to the type's limits, with `errno` set to `ERANGE` |
| `f64("0x1.8p1")` | 3.0 | `strtod`'s hex floats, so `f64(x.hex)` is `x` |

- Every integer type reads text, `i128` and `u128` too.
- `bool` reads none: `bool(p)` of a pointer tells it from `nullptr`, as
  in C, and of a string, which is never `nullptr`, it is an error.
- A base is for text only: after a number it is an error, from kelvinc
  where it sees the number and from C (naming `kv_base_needs_text`)
  where only `_Generic` does.
- A `?:` of texts is text (`i32(argc > 1 ? argv[1] : "8")`).
- Floats are `strtod`'s and `strtof`'s own: out of range is an
  infinity, `errno` is `ERANGE` also when the result is tiny, and the
  decimal point is the one of the C locale in use.
- As for `.size`, a field named like a type wins over the property
  where kelvinc cannot see that the value is no struct, so `o.via.i64`
  of a C struct is its field: there, `i64(v)` converts.
- `.i64` takes no base: write `i64(s, 16)`.

`as` binds like C's cast. It is tighter than every binary operator and
looser than prefix operators, and it chains left to right
*(provisional P17)*:

| Kelvin | Means | C |
|--------|-------|---|
| `-x as u8` | `(-x) as u8` | `(uint8_t)-x` |
| `a * b as i64` | `a * (b as i64)` | `a * (int64_t)b` |
| `x as i64 as i32` | `(x as i64) as i32` | `(int32_t)(int64_t)x` |
| `(p as u8^)[0]` | index the converted pointer | `((uint8_t *)p)[0]` |

- Parenthesize to index or dereference the result of `as`.
  `p as u8^[0]` would read `u8^[0]` as a type.
- Writing a C cast, whether `(i64)x`, `(u8^)p` or `(size_t)n`, is an
  error that suggests `v as T` or `T(v)`.
- `as` binds tighter than `*` too, so
  `malloc(n as size_t * sizeof(i32))` means
  `malloc((n as size_t) * sizeof(i32))`.
- C casts to typedef names are caught as well.
  - `(size_t)n` and `(FILE *)p` get the Kelvin hint.
  - `(size_t)-1`, `(size_t)(n + 1)` and `(int32_t)*p` look like
    arithmetic or a call to Kelvin, so they reach the C compiler, which
    rejects them with "expected expression" at your line. They never
    compile as a cast.


## Powers: `**` and `pow`

```swift
let kib:i64 = 2 ** 10                    // 1024, worked out by kelvinc

let main():int32 {
    let n:i64 = 3
    println(n ** 4, " ", -2 ** 2, " ", 2 ** 3 ** 2, " ", 0 ** 0)   // 81 -4 512 1
    println(n.pow(4), " ", 4.pow(13, 497), " ", 3.pow(-1, 7))      // 81 445 5
    var x:i64 = 5
    x **= 2                              // 25
    println(x, " ", kib)
    return 0
}
```

- **`b ** e`** of two integers is `b` to the power `e`, as Python's
  (#380); see [operators.md](operators.md) for where it binds.
  - It is of `b`'s type, promoted as C promotes a shift's left operand:
    a `u8` or an `i16` gives an `i32`, an `i64` an `i64`, whatever `e`
    is.
  - It wraps as `*` does, as so many multiplications would: `n ** 40`
    of an `i64` 3 is 3^40 mod 2^64, and `w ** 64` of a `u64` 2 is 0.
  - `0 ** 0` is 1.
- **A negative exponent** has no integer power, as a reciprocal is no
  integer.
  - Written so, `2 ** -1` is an error that says to raise a
    floating-point number, `2.0 ** -1`.
  - One known only at run time ends the program, as a division by 0
    does: `kelvin: '**' of integers takes an exponent of 0 or more`.
- **Two literals** are worked out by kelvinc, exactly, into one: so
  `2 ** 40` is 1099511627776, and a global's value may be one.
  - The power is an `i64`, as a literal is: `2 ** 63` is an error that
    says to write `2.0 ** 63`, or `u64(2) ** 63`, which wraps as a
    `u64`.
  - Otherwise a literal base is an `i64` too: `2 ** n` counts past
    `i32`.
- **Its type is seen**, so `let y = n ** 2` needs no written type,
  where `n * 2` does.
- **`b.pow(e)`** is `b ** e`.
- **`b.pow(e, m)`** is `b` to the `e`, mod `m`, as Python's
  `pow(b, e, m)`.
  - It never overflows: the runtime multiplies in 128 bits, so
    `2.pow(1000, m)` of any `m` is exact.
  - The result has `m`'s sign, as Python's `%` gives: `4.pow(13, 497)`
    is 445, and `4.pow(13, -497)` is -52.
  - A negative `e` takes the inverse of `b` mod `m`: `3.pow(-1, 7)` is
    5. Where `b` and `m` share a factor there is none, and the program
    ends.
  - `m` of 0 is an error, written so, and ends the program otherwise.
  - Its type is what C gives `b % m`; `b`, `e` and `m` are integers of
    64 bits or fewer.

## Magnitude: `.abs`

```swift
let main():int32 {
    let n:i64 = -3
    let a:i32 = 3
    let b:i32 = 10
    let least:i8 = -128
    println(n.abs, " ", (a - b).abs, " ", (-5).abs, " ", least.abs)   // 3 7 5 -128
    return 0
}
```

- **`x.abs`** of a signed integer, `i8` to `i128`, is its magnitude, of
  its own type (#381): an `i8`'s is an `i8`.
  - Of arithmetic it is of the type C gives it: `(a - b).abs` of two
    `i32`s is an `i32`, and `(-k).abs` of an `i8` an `i32`, as C
    promotes `-k`.
  - It is a property, with no parentheses, and needs no import.
- **A signed integer's least** has no magnitude its type holds, so it
  stays as it is, as two's complement negates it, wrapping as `-` and
  `**` do: `least.abs` of an `i8` -128 is -128.
- **An unsigned integer** has no `.abs`: it is never negative.
- A struct's field named `abs`, and an attribute of your own, win.

## Sign: `.sign`

- **`x.sign`** of a signed integer is -1, 0 or 1, of its own type, as
  Rust's `signum` (#382): `(-3).sign` is -1, and an `i8`'s is an `i8`.
  - So `x.abs * x.sign == x`, the least too.
  - Of arithmetic it is of the type C gives it, as `.abs` is:
    `(a - b).sign`.
  - It is a property, with no parentheses, and needs no import.
- **An unsigned integer** has no `.sign`, nor a complex number, which
  has no order.
- A struct's field named `sign`, and an attribute of your own, win.

## Properties and methods

| On | Property | Gives |
|---|---|---|
| signed integers | `.abs` | the magnitude, of its type; the least stays as it is (#381) |
| | `.sign` | -1, 0 or 1, of its type (#382) |
| integers | `b ** e` | `b` to the power `e`, of `b`'s promoted type, wrapping; `e` never negative (#380) |
| | `.pow(e)` | `b ** e` (#380) |
| | `.pow(e, m)` | `b` to the `e`, mod `m`, Python's `pow(b, e, m)`, without overflow (#380) |
| | `.size` | `sizeof`, a `size_t` |
| | `.type`, `.typename` | the type, where a type goes; its name as text |
| | `.cstr` | the text, as `print` shows it, in the block's buffer |
| | `.dec`, `.hex`, `.oct`, `.bin` | text in that base, signed ones with a sign, `0x`/`0o`/`0b` prefixed |
| | `.uchr` | the codepoint of the number, a `uchr` (#56) |
| any number | `.i8` ... `.u64`, `.f32`, `.f64`, `.bool` | a conversion, `i64(v)` written after the value |
| text | `.i64` and the others | read a number from text, `i64("42")`; `i64(text, 16)` in a base |

The details are in [properties.md](properties.md); conversions are
above, under [Conversions](#conversions-no-c-casts). A float's
properties are in [floatingpoint.md](floatingpoint.md#properties-and-methods),
and `bool`'s in [bool.md](bool.md#properties-and-methods).
