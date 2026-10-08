# Operators

Kelvin keeps C's operators and C's precedence, with a few spellings
moved: `^` dereferences, `~` is XOR, `:=` assigns a reference, `as`
converts, and assignment, `++` and `--` are statements. This document
is the table, highest precedence first; the other documents say what
each operator means for its types.

## Precedence, highest first

| Level | Operators | Kelvin | C |
|------:|-----------|--------|---|
| 1 | postfix | `p^`, `a[i]`, `f(x)`, `s.m`, `p^.m`, `x.prop`, `x.method()`, `p++`, `p--` (statements) | `*p`, `a[i]`, `f(x)`, `s.m`, `p->m`, `x++` |
| 2 | prefix | `&x`, `-x`, `+x`, `!b`, `~n` | `&x`, `-x`, `+x`, `!b`, `~n` (no `*p`, no `++x`) |
| 3 | conversion | `x as T`, `x:T`, `T(x)` | `(T)x` |
| 4 | `* / %` | `a * b` | `a * b` |
| 5 | `+ -` | `a + b` | `a + b` |
| 6 | `<< >>` | `a << b` | `a << b` |
| 7 | `< <= > >=` | `a < b` (a `bool`) | `a < b` (an `int`) |
| 8 | `== !=` | `a == b` (a `bool`) | `a == b` |
| 9 | `&` | `a & b` | `a & b` |
| 10 | XOR | `a ~ b` | `a ^ b` |
| 11 | `\|` | `a \| b` | `a \| b` |
| 12 | `&&` | `a && b` (`bool`s) | `a && b` |
| 13 | `\|\|` | `a \|\| b` (`bool`s) | `a \|\| b` |
| 14 | `?:` | `c ? a : b` (`c` a `bool`) | `c ? a : b` |
| 15 | ranges | `a..<b`, `a...b` (in `for` only) | |
| 16 | assignment (statements) | `=`, `:=`, `+=`, `-=`, `*=`, `/=`, `%=`, `<<=`, `>>=`, `&=`, `~=`, `\|=` | `=`, `+=`, ..., `^=` |
| 17 | `,` | `a, b` (in a `for` clause, an assignment list) | `a, b` |

So `6 & 3 == 3` is still `6 & (3 == 3)`, as in C, and `a + b as i64`
is `a + (b as i64)`: `as` binds tighter than every binary operator and
looser than the prefix ones, so `-x as u8` is `(-x) as u8`.

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
  reference and `=` for a value (#19), so `a = b = 0` and `if (c = f())`
  are gone, and `while (c = getchar()) != EOF` is written with the call
  in the body. A comma list of assignments runs left to right.
- **`p++` and `p--`** step a `var` pointer, as statements, postfix only
  (#51); `i++` on a number is an error that says `i += 1`, and `++p` an
  error that says `p++`.
- **`a..<b` and `a...b`** are ranges, in `for i in` only (#28).
- **`.`** reaches a field, a method (`x.m()`), a property (`x.size`,
  `s.count`, `p.isNull`) and a type (`v.type`); `x.name(...)` is a
  method call when some type defines the method, a field call
  otherwise. See [properties.md](properties.md).
- **`$0`, `$1`** are an anonymous function's parameters, and `{ ... }`
  after a call is its last argument (#32). See
  [functions.md](functions.md).

## Operators on structs

A struct or union may define `+ - * / % == != < <= > >=` and unary `-`
(#42), as functions named by the operator and chosen by their types:

```kelvin
struct money { cents: i64 }
let +(a:money, b:money):money { (money){a.cents + b.cents} }
let <(a:money, b:money):bool { a.cents < b.cents }
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
