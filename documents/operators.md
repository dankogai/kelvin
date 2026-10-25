# Operators

Kelvin keeps C's operators and C's precedence, with a few spellings
moved: `^` dereferences, `~` is XOR, `:=` assigns a reference, `as`
converts, and assignment, `++` and `--` are statements. This document
is the table, highest precedence first; the other documents say what
each operator means for its types.

**Where it lives:** the core. The operators are C's, placed and typed by kelvinc, with nothing linked; `==` on Strings and the Set algebra call the prelude's functions, in `libkelvin`.

## Precedence, highest first

| Level | Operators | Kelvin | C |
|------:|-----------|--------|---|
| 1 | postfix | `p^`, `a[i]`, `f(x)`, `s.m`, `p^.m`, `x.prop`, `x.method()`, `p++`, `p--` (statements) | `*p`, `a[i]`, `f(x)`, `s.m`, `p->m`, `x++` |
| 2 | prefix | `&x`, `-x`, `+x`, `!b`, `~n`, `try r` | `&x`, `-x`, `+x`, `!b`, `~n` (no `*p`, no `++x`) |
| 3 | conversion | `x as T`, `x:T`, `T(x)` | `(T)x` |
| 4 | `* / %` | `a * b` | `a * b` |
| 5 | `+ -` | `a + b` | `a + b` |
| 6 | `<< >>` | `a << b` | `a << b` |
| 7 | ranges | `a..<b`, `a...b`, `a...`, `..<b`, `...b`, a `Range<T>` (#373) | |
| 8 | `< <= > >=` | `a < b` (a `bool`) | `a < b` (an `int`) |
| 9 | `== !=` | `a == b` (a `bool`) | `a == b` |
| 10 | `&` | `a & b` | `a & b` |
| 11 | XOR | `a ~ b` | `a ^ b` |
| 12 | `\|` | `a \| b` | `a \| b` |
| 13 | `&&` | `a && b` (`bool`s) | `a && b` |
| 14 | `\|\|` | `a \|\| b` (`bool`s) | `a \|\| b` |
| 15 | `?? !!` | `x ?? d`, an Optional's value or `d` (#72); `d0 ?? d1` and `d0 !! d1` of Dictionaries, `d0`'s values kept or `d1`'s taken (#237); right to left, `a ?? b ?? 0` is `a ?? (b ?? 0)` (#251); `a ?? b` of two `T?` a `T?` (#252), of two Results a Result (#253) | |
| 16 | `?:` | `c ? a : b` (`c` a `bool`); `c ? v : none` where a `T?` is expected (#116) | `c ? a : b` |
| 17 | assignment (statements) | `=`, `:=`, `+=`, `-=`, `*=`, `/=`, `%=`, `<<=`, `>>=`, `&=`, `~=`, `\|=`; `??=`, `!!=` of Dictionaries (#237) and of an entry, `d[k] ??= v` (#243) | `=`, `+=`, ..., `^=` |
| 18 | `,` | `a, b` (in a `for` clause, an assignment list) | `a, b` |

So `6 & 3 == 3` is still `6 & (3 == 3)`, as in C, and `a + b as i64`
is `a + (b as i64)`: `as` binds tighter than every binary operator and
looser than the prefix ones, so `-x as u8` is `(-x) as u8`.

The binary operators group left to right, as C's, but for `??` and
`!!`, which group right to left, as Swift's `??` (#251): `a ?? b ?? 0`
is `a ?? (b ?? 0)`, the first value of the chain or 0.

## What moved, and why

- **`p^`** dereferences, postfix (#3), so a chain reads left to right:
  `p^.m`, `p^[i]`, `pp^^`. `*` is only multiplication, and `*p` on a
  line of its own is an error with the hint; `->` too.
- **`a ~ b`** is XOR and `a ~= b` its assignment (#4), since `^` means
  pointer; unary `~` is still bitwise NOT, and `p^ = x` is always an
  assignment through `p`.
- **`&x`** is C's address-of, with a `let`'s address pointing to
  `const`; see [pointers.md](pointers.md).
- **`x as T`, `x:T` and `T(x)`** replace C's cast, `(T)x`, which is an
  error with a hint; `T(x)` also reads a number from text (#36). See
  [integers.md](integers.md).
- **Comparisons, `&&`, `||` and `!`** give a `bool` and take `bool`s
  (#23): `if n` is an error that says `if n != 0`. See
  [flow-controls.md](flow-controls.md).
- **`=` and `:=`** are statements with no value (#26), `:=` for a
  reference and `=` for a value (#19).
  - So `a = b = 0` and `if (c = f())` are gone, and
    `while (c = getchar()) != EOF` is written with the call in the body.
  - A comma list of assignments runs left to right.
- **`p++` and `p--`** step a `var` pointer, as statements, postfix only
  (#51).
  - `i++` on a number is an error that says `i += 1`, and `++p` an
    error that says `p++`.
- **`a..<b` and `a...b`** are ranges, in `for i in` (#28) and as values,
  `Range<T>`, with `a...`, `..<b` and `...b` (#373): see
  [ranges.md](ranges.md).
- **`.`** reaches a field, a method (`x.m()`), a property (`x.size`,
  `s.count`, `p.isNull`) and a type (`v.type`).
  - `x.name(...)` is a method call when some type defines the method, a
    field call otherwise. See [properties.md](properties.md).
- **`$0`, `$1`** are an anonymous function's parameters, and `{ ... }`
  after a call is its last argument (#32). See
  [functions.md](functions.md).

## Operators on structs

A struct or union may define `+ - * / % == != < <= > >=` and unary `-`
(#42), as functions named by the operator and chosen by their types:

```swift
struct money { cents: int64 }
extend money {
    static let +(a:Self, b:Self):Self { (Self){a.cents + b.cents} }
    static let <(a:Self, b:Self):bool { a.cents < b.cents }
}
```

Then `a + b`, `a < b` and `b += a` call them, with C's precedence; `<<`,
`!` and `+=` cannot be defined, and `x op= y` is `x = x op y`. See
[structs.md](structs.md).

## Not operators

- `sizeof x` and `sizeof(T)` are C's; `x.size` is the same (#21).
- There is no `,` operator in an expression: a list of assignments is a
  statement, and a `for` clause takes one.
- There is no `?:` on templates' room: `c ? `a` : `b`` is text, and the
  longer arm sizes it (#44).
