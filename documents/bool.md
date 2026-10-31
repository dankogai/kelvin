# `bool`

A truth value: `true` or `false`.

## Synopsis

<!-- fragment -->
```swift
var done = false                    // a bool, inferred
let ok = a < b                      // a comparison gives a bool
let both = ok && f(x)               // so do &&, || and !
if done { println("finished") }     // a condition is a bool, with no parentheses
println(a == b, " ", ok.cstr)       // true or false
let set = bool(flags & 4)           // a number to a bool: zero is false
```

## Description

`bool` is Kelvin's truth value, `true` or `false`, and every condition
is one. This document has the type, where a `bool` comes from, how it
converts and prints. Integers are in [integers.md](integers.md) and
floats in [floatingpoint.md](floatingpoint.md).

| Kelvin | C |
|--------|---|
| `bool` | `bool` from `<stdbool.h>`, i.e. `_Bool` |

- **The type:** `bool`, with the values `true` and `false`, which are
  built in *(provisional P14)*.
  - C's `_Bool` is an error that suggests `bool`.
  - Neither `<stdbool.h>` nor any header is needed: the generated C
    includes it.
- **Where a `bool` comes from** (#23):
  - Comparisons, `&&`, `||` and `!` give a `bool`, not C's `int`, so
    `println(a == b)` prints `true` or `false`; see
    [operators.md](operators.md).
  - A `bool` variable, field or function result is one as it is.
  - `!!n` (#387) is the `bool` of an integer 0 or 1, a bit: `false` of
    0, `true` of 1, and any other ends the program; `bv[n]` of a
    `Bits` is one; see [bits.md](bits.md).
- **Inference** (#24, #25): `var done = false`, `let ok = a < b` and
  `let both = ok && f(x)` are `bool`s, as is the `bool` result of a
  Kelvin function or method; see [grammar.md](grammar.md).
  - A `bool` from a C function needs its type written:
    `let ok:bool = isdigit(c) != 0`.
- **Conditions are `bool`:** those of `if`, `while`, `do` and `for`, and
  the first operand of `?:`; a number or a pointer is compared first,
  `x != 0`, `p != nullptr`; see [flow-controls.md](flow-controls.md).
- **Converting:** `bool(x)`, `x as bool` and `x.bool` convert as C's cast
  does: zero is `false` and anything else `true`; see
  [integers.md](integers.md#conversions-no-c-casts).
  - `bool(p)` of a pointer tells it from `nullptr`, as in C.
  - The way back, `i64(b)` or `b.i64`, is 0 or 1.
  - `bool` reads no text: `bool(s)` of a string, which is never
    `nullptr`, is an error.
- **Printing:** `print` shows `true` or `false`, and so does `.cstr`;
  see [printing.md](printing.md).

## Where it lives

The core. `bool` is C's `bool` from `<stdbool.h>`, which the generated C includes itself, with nothing linked. Printing it and its text (`.cstr`) are the prelude's, `libkelvin`, linked without an import.

## Properties and methods

| On | Property | Gives |
|---|---|---|
| `bool` | `.size` | `sizeof`, a `size_t` |
| | `.align` | `alignof(bool)`, a `size_t` (#395) |
| | `.type`, `.typename` | the type, where a type goes; its name, `bool` |
| | `.cstr` | `true` or `false`, in the block's buffer |
| | `.i8` ... `.u64`, `.f32`, `.f64` | a conversion, `i64(v)` written after the value: 1 or 0 |
| integer | `!!n` | the `bool` of 0 or 1, `false` or `true`; any other ends the program (#387) |

The details are in [properties.md](properties.md).
