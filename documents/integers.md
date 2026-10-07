# Integers, floats and `bool`

Every number in Kelvin says its size. This document has the numeric
types, their literals, the two ways to convert, and how a number is read
from text. The text of a number (`n.cstr`, `n.hex`) is in
[properties.md](properties.md), and `print`'s view of it in
[printing.md](printing.md).

## Numeric types always say their size

| Kelvin | C |
|--------|---|
| `i8` `i16` `i32` `i64` | `int8_t` `int16_t` `int32_t` `int64_t` |
| `u8` `u16` `u32` `u64` | `uint8_t` `uint16_t` `uint32_t` `uint64_t` |
| `i128` `u128` | `__int128`, `unsigned __int128` (where the C compiler has them) |
| `f32` `f64` | `float`, `double` |
| `bool` | `bool` from `<stdbool.h>`, i.e. `_Bool` |

C's `char`, `short`, `int`, `long`, `signed`, `unsigned`, `float`, `double`
and `_Bool` are errors that suggest the Kelvin name. As a result:

- There is no plain `char`. Use `u8`, or `i8` for signed bytes; see
  [cstrings.md](cstrings.md) for text.
- `long double` has no Kelvin spelling yet.
- `true` and `false` are built in *(provisional P14)*.
- `f32 _Complex` and `f64 _Complex` are C's complex types.

Kelvin's built-in types need no header, and neither do `<stdint.h>` and
`<stdbool.h>`, because the generated C includes those two itself.

## Literals

Literals carry no size or type hints. C's suffixes `u`, `l`, `ll` and `f`
(`10UL`, `10u`, `1.5f`, `1.5L`) are errors. The type belongs on the
declaration, or on the value as an annotation (`10:u64`):

| C | Kelvin |
|---|--------|
| `unsigned long v = 10UL;` | `var v:u64 = 10` |
| `float f = 1.5f;` | `var f:f32 = 1.5` |
| `long long n = 10LL;` | `var n = 10` (or `var n:i64 = 10`) |

Everything else about literals is C's: hex `0xff`, octal `017`, binary
`0b101`, exponents `1e9`, hex floats `0x1p4`, character constants `'a'`,
and adjacent strings. A literal inside an expression still has C's type, so
a bare `1` is C's `int` (an `i32`). Where C would write `1UL << 40`, Kelvin
writes `1:u64 << 40`.

## Conversions (no C casts)

C's `(T)v` does not exist in Kelvin. There are two ways to convert, and
both mean exactly what the C cast means (`i32(3.9)` is 3, `u8(300)` is 44),
except that a converter of text reads the number in it (#36), while
`s as i64` and `s:i64` stay C's cast:

- **`T(v)`**, a converter, for built-in types: `i32(x)`, `u8(c)`,
  `f64(n) / 2`, `bool(flags & 4)` *(provisional P18)*. Of text, it reads
  the number (#36, below).
- **`v:T`**, a type annotation, means exactly `v as T`: `0xdead:u16`,
  `1:u64 << 40`, `n:size_t`. In the middle of a ternary (`c ? a : b`)
  and in a `case` label, a bare name after `:` is the separator, so
  annotate with a typedef there by using parentheses or `as`.
- **`v as T`**, for any type, including pointers and C typedef names:
  `malloc(n) as i32^`, `p as any^`, `n as size_t`.

### Numbers from text

A converter reads a number from text (#36): `i64("42")`, `f64("1.5")`,
and with a base from 2 to 36 for an integer type, `i32("755", 8)`. The
property form is the same converter: `"42".i64` is `i64("42")`, and
`n.u8` is `u8(n)` for a number. Text is a string, `cstr`, `u8^`, `i8^`,
an array of `u8` or `i8`, the text of a property such as `n.hex`, or C's
`char *`. Every other value converts as before. Where kelvinc cannot
see the type, C's `_Generic` makes the choice.

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

Every integer type reads text, `i128` and `u128` too. `bool` reads
none: `bool(p)` of a pointer tells it from `nullptr`, as in C, and of a
string, which is never `nullptr`, it is an error. A base is for text
only: after a number it is an error, from kelvinc where it sees the
number and from C (naming `kv_base_needs_text`) where only `_Generic`
does. A `?:` of texts is text (`i32(argc > 1 ? argv[1] : "8")`).

Floats are `strtod`'s and `strtof`'s own: out of range is an infinity,
`errno` is `ERANGE` also when the result is tiny, and the decimal point
is the one of the C locale in use.

As for `.size`, a field named like a type wins over the property where
kelvinc cannot see that the value is no struct, so `o.via.i64` of a C
struct is its field: there, `i64(v)` converts. `.i64` takes no base:
write `i64(s, 16)`.

`as` binds like C's cast. It is tighter than every binary operator and
looser than prefix operators, and it chains left to right
*(provisional P17)*:

| Kelvin | Means | C |
|--------|-------|---|
| `-x as u8` | `(-x) as u8` | `(uint8_t)-x` |
| `a * b as i64` | `a * (b as i64)` | `a * (int64_t)b` |
| `x as i64 as i32` | `(x as i64) as i32` | `(int32_t)(int64_t)x` |
| `(p as u8^)[0]` | index the converted pointer | `((uint8_t *)p)[0]` |

Parenthesize to index or dereference the result of `as`. `p as u8^[0]`
would read `u8^[0]` as a type. Writing a C cast, whether `(i64)x`,
`(u8^)p` or `(size_t)n`, is an error that suggests `v as T` or `T(v)`.
`as` binds tighter than `*` too, so `malloc(n as size_t * sizeof(i32))`
means `malloc((n as size_t) * sizeof(i32))`.

C casts to typedef names are caught as well. `(size_t)n` and `(FILE *)p`
get the Kelvin hint. `(size_t)-1`, `(size_t)(n + 1)` and `(int32_t)*p` look
like arithmetic or a call to Kelvin, so they reach the C compiler, which
rejects them with "expected expression" at your line. They never compile
as a cast.

