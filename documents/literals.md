# Literals: what is written and what is made

A literal is a value written in the source, which kelvinc reads and checks. This document pairs each kind of literal with its counterpart: the value read from text at run time, or the one made on the heap.

## Synopsis

```swift
let main():int32 {
    let a = [0, 1]                      // a fixed array, [i64](2): where it is declared
    var xs = $[0, 1]                    // an Array<i64>: on the heap, owned, grows
    xs += 2
    println(a, " ", xs, " ", xs.typename)          // [0, 1] [0, 1, 2] Array<i64>
    let s := "héllo"                    // a cstr: C's literal, for the whole program
    var u = $"héllo"                    // a String: on the heap, owned
    println(s.count, " ", u.count)                 // 6 5: bytes, and graphemes
    println(1_000, " ", i64("1_000"))              // 1000 1: a literal, and text read at run time
    println(123456789012345678901234567890n, " ", BigInt("12x"))   // 123456789012345678901234567890n 12n
    println(u8(300), " ", 300 as u8)               // 255 44: let c:u8 = 300 is an error
    return 0
}
```

## Description

Three questions tell the literals and their counterparts apart:

- **When is it read?** A literal is read and checked by kelvinc, when the program is compiled. Text is read when the program runs, as C reads it.
- **Where does it live?** A literal's value lives in the program or where it is declared. A `$` form makes an owner on the heap.
- **What type is it?** A literal has no suffix; its type comes from where it goes.

### Read when compiled, or when the program runs

| Literal | At run time | What differs |
|---|---|---|
| `1_000` | `i64("1_000")` | the literal is 1000; the text is 1, read to the `_` |
| `0xff`, `0o17`, `0b101` | `i64("ff", 16)`, `i64("17", 8)`, `i64("101", 2)` | text is base 10 unless a base is given: `i64("0xff")` is 0 |
| `1.5`, `1e9`, `0x1p4` | `f64("1.5")` | the same value; text is `strtod`'s |
| `inf`, `nan` | `f64("inf")`, `f64("nan")` | the same value |
| `123n` | `BigInt("123")` | the same value; text may be a variable's |
| `300` into a `u8` | `u8("300")` | the literal is an error; the text is 255, clamped |

- **A literal is checked.** What is wrong with one is kelvinc's error, at its line and column:
  - a malformed one, `0x_ff` or `1e_5`;
  - a C suffix, `10u`, `10UL`, `1.5f`;
  - one that does not fit its type, `let c:u8 = 300` (#663), which says `300 does not fit u8, whose values are 0 to 255`;
  - one past u64's greatest, which no integer type holds, `99999999999999999999` (#678), which says a BigInt is written `99999999999999999999n`.
- **Text is read, never refused.** A converter reads it as C's `strtol` and `strtod` do (#36):
  - leading spaces and a sign, then the longest number: `i64("42abc")` is 42;
  - no number is 0: `i64("abc")`, `BigInt("")`;
  - past the type's range is its limit, with `errno` set to `ERANGE`: `i8("300")` is 127.
  - The table of what is read is in [integers.md](integers.md#numbers-from-text).
- **A `_` among the digits** is of literals alone (#671).
  - `1_000_000`, `0x7fff_ffff`, `1_000.000_1` and `1_000n` leave it out.
  - Text never has one: `i64("1_000")` is 1, and what `print` writes reads back.
- **A `BigInt` literal is whole at any length:** `123456789012345678901234567890n` is `BigInt("123456789012345678901234567890")` (#508).
  - `BigInt(n)` takes a value of an integer type, so a longer number is written with its `n`.
  - See [bigint.md](bigint.md).

### Where it lives

| Literal | Its value | The `$` form | Its value |
|---|---|---|---|
| `[0, 1]` | a fixed array, `[i64](2)` | `$[0, 1]` | an `Array<i64>` |
| `["a", "b"]` | a `[cstr](2)` | `$["a", "b"]` | an `Array<String>` (#616) |
| `"ab"` | a `cstr` | `$"ab"` | a `String` |
| `` `n=${n}` `` | a `cstr` on the block's stack | `` $`n=${n}` `` | a `String` |
| `{1, 2}` | a struct's value, where its type is written | `${"a": 1}`, `${1, 2}` | a `Dictionary<String, i64>`, a `Set<i64>` |

- **A fixed array**, `[0, 1]`, lives where it is declared: on the stack of a function, or in the program at the top level.
  - Its count never changes: `a += 2` is an error.
  - Passed to a function, it is a pointer, as in C.
  - See [arrays.md](arrays.md).
- **A string literal**, `"ab"`, is C's: a `cstr` that lives for the whole program and cannot be written through.
  - It has no `+`: `"a" + "b"` is an error that says to make one a String.
  - Its `.count` is its bytes: `"héllo".count` is 6.
  - See [cstr.md](cstr.md).
- **A template**, `` `n=${n}` ``, is a `cstr` on the stack of its block, until the block ends: see [printing.md](printing.md).
- **`{...}`** is C's initializer: a struct's or a union's value, where its type is written, `let p:point = {1, 2}` (#48).
- **A `$` form** makes an owner on the heap: freed when its block ends, moved by `return` and by passing, copied only by `.copy()`.
  - `$[...]` is an Array that grows, `xs += 2`.
  - `$"..."` is a String, with `+`, whose `.count` is its graphemes: `$"héllo".count` is 5.
  - `${k: v}` is a Dictionary, and `${a, b}` a Set.
  - **The `$` reaches every literal inside it** (#616): `$["a"]` is an `Array<String>`, and a `{k: v}` within a Dictionary.
  - See [ownership.md](ownership.md), [strings.md](strings.md), [dictionaries.md](dictionaries.md) and [sets.md](sets.md).

### What type a literal is

| Literal | Its type |
|---|---|
| `42`, `0xff`, `'a'` | from where it goes; `let n = 42` is an `i64`, and `'a'` a `u8` |
| `1.5`, `inf` | from where it goes; `let d = 1.5` is an `f64` |
| `123n` | a `BigInt` |
| `true`, `false` | a `bool` |
| `"ab"`, `"""..."""`, a template | a `cstr` |
| `[0, 1]` | an array of its items' type, `[i64](2)` |

- **No suffix:** the type belongs on the declaration, `var v:u64 = 10`, or on the value, `10:u64`.
- **Inferred**, an integer literal is an `i64` and a floating one an `f64` (#47).
  - So `let x = 18446744073709551615` is an error, as it does not fit an `i64` (#678): write `let x:u64 = 18446744073709551615`.
  - Arithmetic of literals alone is reckoned in 64 bits: `let big = 65536 * 65536` is 4294967296.
- **Beside a variable**, a literal has C's type, so a bare `1` is C's `int`:
  - `let x:i64 = 1 << 40` is an error that says to write `1:i64 << 40` (#665).
- **Three ways to put a number into a type:**
  - `let c:u8 = 300` is an error: a literal must fit (#663).
  - `u8(300)` is 255: a converter gives the nearest value (#513).
  - `300 as u8` is 44: `as` is C's conversion, which wraps.
  - See [integers.md](integers.md#conversions-no-c-casts).

## Where it lives

The core. Literals are kelvinc's own; a `BigInt`'s and a `$` form's values are of the prelude, which needs no import.
