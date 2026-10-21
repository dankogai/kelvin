# Kelvin design

This file holds the cumulative design results. How each decision was reached
is recorded in [Dialogue.md](Dialogue.md), and a C programmer's guide to the
differences is in [documents/versusC.md](documents/versusC.md), with a
document per topic beside it.

## Principles

- **A quiet alternative to C.** No bloat, and no intention of becoming C++.
- **100% C ABI compatibility.** A Kelvin program is a C program with
  different spelling. Types, layout, calling conventions and semantics are
  C's.
- **Start with bare C and change it bit by bit.** Every departure from C is
  proposed, discussed and agreed on one at a time, then recorded here.
- **The preprocessor is TODO**, except `#import <x.h> as C` (#12).

### The name

C is also the symbol for Celsius, and Kelvin is its natural successor. The
step size is the same, so everything you know about C carries over one to
one, but it sits on an absolute scale. The source extension is `.k`.

## Status: v0.0.1 (bare C baseline)

`kelvinc` translates Kelvin into C and hands the result to the C compiler
(`$CC`, which defaults to `cc`). It has no type checker of its own. The C
compiler checks everything, so semantics and ABI are C's by construction.
`#line` directives make C compiler diagnostics point at the `.k` source.

## Agreed changes from C

| # | Change | C | Kelvin | Agreed |
|---|--------|---|--------|--------|
| 1 | The type comes after the name | `int x = 0;` | `x:i32 = 0;` | 2026-10-01 |
| 2 | Postfix `^` for pointer types | `char *p;` | `p:u8^;` | 2026-10-01 |
| 3 | Postfix `^` to dereference | `*p`, `p->m` | `p^`, `p^.m` | 2026-10-01 |
| 4 | XOR is binary `~` | `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` | 2026-10-01 |
| 5 | Functions use `name:type` too, with no `fn` and no `->` | `long add(long a, long b)` | `add(a:i64, b:i64):i64` | 2026-10-01 |
| 6 | Integer types always say their size, and are built in | `int32_t` (via `<stdint.h>`) | `i8 i16 i32 i64 u8 u16 u32 u64`, plus `i128 u128` where available | 2026-10-01 |
| 7 | C's integer names are gone | `char`, `short`, `int`, `long`, `signed`, `unsigned` | `u8` (or `i8`), `i16`, `i32`, `i64`/`u64`, ... | 2026-10-01 |
| 8 | An inferred integer is `i64`; a written type is always explicit | | `i = 42;` is `i:i64 = 42;` | 2026-10-01 |
| 9 | Floating-point types say their size too | `float`, `double` | `f32`, `f64` | 2026-10-01 |
| 10 | `bool` is built in | `_Bool` (or `bool` via `<stdbool.h>`) | `bool` | 2026-10-01 |
| 11 | An inferred C double literal is `f64` | `double d = 1.5;` | `d = 1.5;` | 2026-10-01 |
| 12 | C headers are importable | `#include <stdio.h>` | `#import <stdio.h> as C` | 2026-10-01 |
| 13 | Literals carry no size hints; the declaration carries the type | `10UL`, `1.5f` | `val:u64 = 10`, `f:f32 = 1.5` | 2026-10-01 |
| 14 | No `(T)v` casts: convert with `T(v)` or `v as T` | `(int)x`, `(int *)malloc(n)` | `i32(x)`, `malloc(n) as i32^` | 2026-10-01 |
| 15 | ~~No `var`: `x:T = v` declares, and so does `x = v` when `x` is not declared yet~~ (superseded by #27) | `int32_t x = 0; long i = 42;` | `x:i32 = 0; i = 42;` | 2026-10-01 |
| 16 | `expr:T` annotates any expression; it means `expr as T` | `(uint16_t)0xdead`, `1UL << 40` | `0xdead:u16`, `1:u64 << 40` | 2026-10-01 |
| 17 | A prelude with `print()` and `println()`, in `libkelvin.{a,so,dylib}` | `printf("%" PRId64 "\n", n)` | `println(n)` | 2026-10-01 |
| 18 | Every type has methods; ~~`toString()` is mandatory; `fmt()` a la Raku~~ (shelved by #22) | | `point.area():f64 { ... }` | 2026-10-01 |
| 19 | `:=` assigns references (pointers); `=` assigns values | `int64_t *buffer = malloc(8 * 1024); p = q;` | `buffer := malloc(8 * 1024):i64^; p := q;` | 2026-10-01 |
| 20 | No `void`: `any^` is C's `void *`, `nullptr` is `(void *)0`, and `ptr:any^;` means `ptr := nullptr` | `void *p = NULL;` | `p:any^;` | 2026-10-02 |
| 21 | Properties: `x.size` is `sizeof(x)`; integers have `.dec`, `.hex`, `.oct` and `.bin`, and `f32`/`f64` have `.dec` and `.hex`, as `u8^` text in a stack buffer | `sizeof x`, `snprintf(buf, n, "0x%x", x)` (unsigned `x`) | `x.size`, `x.hex` | 2026-10-02 |
| 22 | `toString()`, `fmt()` and `String` are shelved until Kelvin has a true string type. Every type has `.cstr`, its text as `cstr` on the stack, and `cstr` is a built-in name for `u8^` | `snprintf(buf, n, "%lld", x)`; `char *s` | `x.cstr`; `s:cstr` | 2026-10-02 |
| 23 | `if`, `while` and `do` take a condition without parentheses and a block body; every condition, and every operand of `&&`, `||` and `!`, is a `bool`; comparisons and logical operators give a `bool` | `if (n) x = 1;`, `while (fgets(b, n, f))` | `if n != 0 { x = 1; }`, `while fgets(b, n, f) != nullptr { ... }` | 2026-10-03 |
| 24 | `true` and `false` infer `bool` | `bool t = true;` | `t = true;` | 2026-10-03 |
| 25 | A `bool` expression infers `bool` | `bool ok = a < b;` | `ok = a < b;` (and any seen type since #47) | 2026-10-03 |
| 26 | Assignment is a statement; `++` and `--` are gone; pointers step with `.next` and `.prev` | `*p++ = *q++;`, `a = b = 0;` | `p^ = q^; p := p.next; q := q.next;`, `a = 0, b = 0;` | 2026-10-03 |
| 27 | `let` and `var` declare, with the type after the name: a `let` never changes (C's `const`); parameters are lets unless written `var`; a plain `x = v` only assigns | `const int k = 42; int n = 0;` | `let k = 42; var n:i32 = 0;`, `f(var p:u8^)` | 2026-10-03 |
| 28 | Ranges: `for i in a..<b { }` and `for i in a...b { }`, with `i` a `let` | `for (int i = 0; i < n; i++)` | `for i in 0..<n { ... }` | 2026-10-03 |
| 29 | A `struct`, `union` or `enum` is a type by its bare name, as if typedef'd | `typedef struct point point;`, `struct point p;` | `var p:point;` | 2026-10-03 |
| 30 | `for x in s { }` walks a sequence that ends at a terminator: a string up to its NUL, a list along `next`, an array of known length | `while (*s) { c = *s++; ... }` | `for c in s { ... }` | 2026-10-03 |
| 31 | A function type is a function's head without names, `(T, U):R`: C's pointer to a function | `int (*cmp)(const void *, const void *);` | `var cmp:(const any^, const any^):i32;` | 2026-10-03 |
| 32 | Anonymous functions `{ ... }`, which enclose nothing. `$0`, `$1` or `$[k]` are the parameters where kelvinc sees their types, and `{ (a:T, b:U):R in ... }` writes them elsewhere. A body of one expression is the result, and the last argument of a call may follow the call | a `static` function written only to be passed | `sort(xs, n) { $0 < $1 }` | 2026-10-03 |
| 33 | Anonymous functions are inline by default: C's `static inline` | `static inline bool before(int64_t a, int64_t b)` | `{ $0 < $1 }` | 2026-10-04 |
| 34 | Every variable has `v.type`, its type, used where a type goes, and `v.typename`, its Kelvin spelling as `cstr` | `__typeof__(v) w;` | `var w:v.type;`, `v.typename` | 2026-10-04 |
| 35 | A `;` may be left out at the end of a line, and a function whose body is one expression returns it, unless kelvinc sees it has no value or the function is `main`. In a function with a result, `return` at the end of a line takes the next line | `x = 1;`, `long sq(long x) { return x * x; }` | `x = 1`, `sq(x:i64):i64 { x * x }` | 2026-10-04 |
| 36 | Converters read numbers from text, as C's `strtol` and `strtod` do, with an optional base for integers; `text.T` is `T(text)` | `strtol(s, NULL, 8)`, `atof(s)` | `i32("755", 8)`, `f64(s)`, `"42".i64` | 2026-10-05 |
| 37 | Pointers and functions have `.addr`, their address as a `uintptr_t`, and `.hex`, `0x` and all its digits | `(uintptr_t)p`, `printf("%p", p)` | `p.addr`, `p.hex` | 2026-10-05 |
| 38 | What kelvinc writes is named `_kv_`, after its source: `_kv_n_text`, `_kv_i_count`, `_kv_main_fn` | (no C counterpart) | `uint8_t _kv_n_text[36];` instead of `kv_text3` | 2026-10-05 |
| 39 | Template literals: `` `...` `` may span lines, and `${expression}` is the expression's text as `print` shows it; the text is on the heap, freed when the enclosing block ends (on the stack since #44) | `snprintf(buf, n, "Hello, %s!", name)` | `` `Hello, ${name}!` `` | 2026-10-05 |
| 40 | `#import` of a Kelvin file brings in its source, once per program: `"x.k"` next to the importing file, `<lib/x.k>` from Kelvin's home (`<x.k>` from `modules/` since #46) | `#include "x.h"` and a separately compiled `x.c` | `#import <lib/complex.k>` | 2026-10-05 |
| 41 | Functions overload: one name may have several parameter lists, chosen by the arguments' types, and a Kelvin function of a C function's name overloads C's | `csin(z)` beside `sin(x)` | `sin(z:complex64):complex64` beside C's `sin(x)` | 2026-10-05 |
| 42 | A struct or union may define operators: `+ - * / % == != < <= > >=`, and unary `-` | `cadd(a, b)` | `+(a:complex64, b:complex64):complex64 { ... }`, then `a + b` | 2026-10-05 |
| 43 | `lib/complex.k` (`modules/complex.k` since #46): `complex32` and `complex64`, with arithmetic and the elementary functions, without C's `_Complex` | `double complex z = 1.0 + 2.0 * I;` | `let z:complex64 = complex64(1.0, 2.0)` | 2026-10-05 |
| 44 | Template literals use no heap: the text is in a buffer at the top of the enclosing block, with room for each value's longest text, and a string value longer than 256 bytes is cut with `...` | `char buf[N]; snprintf(buf, sizeof buf, "%s", name)` | `` `Hello, ${name}!` ``, as before | 2026-10-06 |
| 45 | A top-level function, method or operator is declared with `let`, as a value that never changes is | `long add(long a, long b)` | `let add(a:i64, b:i64):i64` | 2026-10-06 |
| 46 | `lib/` is `modules/`, which also holds `kelvin_prelude.h` and `libkelvin`; `<x.k>` is looked for in `./modules`, then in Kelvin's `modules/`, where C also looks for headers and libraries | `-I`, `-L` and `#include <x.h>` | `#import <complex.k>` | 2026-10-06 |
| 47 | A declaration infers its type from any value whose type kelvinc sees: a Kelvin function's result, a variable, a field, `&x`, ... but not arithmetic, nor what only C sees | `struct complex64 z = complex64(0.0, 1.0);` | `var z = complex64(0.0, 1.0)` | 2026-10-06 |
| 48 | An array is initialized with `[...]`; a struct or union keeps `{...}` | `int a[3] = {1, 2, 3};` | `let a:i32[3] = [1, 2, 3]` (`let a:[i32](3)` since #49), `let a = [1, 2, 3]` | 2026-10-06 |
| 49 | An array type is `[T]`, as Swift writes it, or `[T](N)` with its count; `.count` is the count, set when the array is made and never changed; `[T](n)` makes n zero-filled elements | `int64_t a[4] = {0, 1, 2, 3}; sizeof a / sizeof a[0]` | `var a = [0, 1, 2, 3]`, `a.count` | 2026-10-07 |
| 50 | Pointers and functions have `.isNull`, `p == nullptr` as a `bool` | `if (p == NULL)` | `if p.isNull` | 2026-10-07 |
| 51 | `p++` and `p--` step a `var` pointer, as statements, postfix only | `p++;` | `p++` | 2026-10-08 |
| 52 | `cstr` is immutable text, stricter than `char *`: no writes through it, no stepping, `.count` is its length; a `u8^` may take it, not encouraged | `const char *s; strlen(s)` | `var s:cstr := "..."; s.count` | 2026-10-08 |
| 53 | A struct or union may define its text: `let T.cstr():cstr { `...` }`, one template literal, written into the caller's buffer | a `to_string(T, buf, n)` by hand | `let vector2d.cstr():cstr { `(${self.x}, ${self.y})` }` | 2026-10-09 |
| 54 | `Bytes`, the first owner on the heap: a growable array of `u8` that its variable owns and its block frees, moved by `return` and by passing, copied only by `.copy()`, borrowed as `Bytes^`, never given to C by value | `malloc`, `realloc`, `free` by hand | `var b = Bytes("hi"); b += "!"` | 2026-10-09 |
| 55 | `String`: Unicode codepoints as UTF-8 on a `Bytes`, an owner under the same rules; malformed text is refused; `for c in s` by codepoint, `s.count` the codepoints, `s.bytes` a read-only borrow | a UTF-8 string by hand | `var s = String("héllo"); s += " 🌍"` | 2026-10-09 |
| 56 | `uchr`: a codepoint on the stack, shown as its UTF-8 by `print`, templates and `.cstr`; `.utf32` and `.codepoint` its number; `n.uchr` and `uchr(x)` make one, U+FFFD where `x` is none; `for c in s` gives one | `uint32_t cp;` and encoding by hand | `for c in s { print(c) }`, `c.utf32` | 2026-10-09 |
| 57 | `Array<T>`: a growable array of `T` on the heap, an owner under the rules of #54, `T` any value type or a `Bytes`, `String` or `Array`, which it owns | `T *xs = malloc(...); realloc(...); free(xs);` | `var xs = Array<i64>(); xs += 1; xs[0]` | 2026-10-09 |
| 58 | `Array([a, b, c])`: an Array of the elements written, `T` inferred from them, or `Array<T>([a, b, c])`; a `[...]` among them is an Array in turn, `Array([[0], [0]])` an `Array<Array<i64>>`; `Array(a)` of a fixed array and `Array(&other)` infer `T` too | `memcpy(xs.at, (int64_t[]){0, 1, 2, 3}, ...)` | `var va = Array([0, 1, 2, 3])` | 2026-10-09 |
| 59 | A struct with no tag, written by its members where a type goes: `{x:f64, y:f64}`; one C struct per spelling, so two written alike are one type | `struct { double x, y; } v = {0, 0};` | `var v:{x:f64, y:f64} = {0.0, 0.0}` | 2026-10-10 |
| 60 | A union with no tag, `union{i:i32, f:f32}`, as #59's struct; `struct{...}` spells #59's too | `union { int i; float f; } u;` | `var u:union{i:i32, f:f32}` | 2026-10-10 |
| 61 | An enum whose cases carry values is a union that knows its case at run time, with one byte for the tag: `enum json { null; n: f64; s: String; a: Array<json> }`, Swift's enum; `json.n(1.5)`, `{.n = 1.5}`, `j.n = 1.5`, `j.n` checked, `j.is(n)`, `j.case`, `switch (j) { case n: ... }`; a struct that owns is copied with `.copy()` and may be an Array's element | `struct { uint8_t tag; union { double n; ... } u; }` and a switch on the tag by hand | `var j = json.n(1.5)`, `if j.is(n) { ... j.n ... }` | 2026-10-10 |
| 62 | `$"text"` is `String("text")` and `$[a, b, c]` is `Array([a, b, c])`, for short; inside an anonymous function `$[k]` is still its parameter | `kv_string_of("text")` | `var s = $"I needed it"`, `var m = $[[1, 0], [0, 1]]` | 2026-10-10 |
| 63 | `switch` is Swift's: no parentheses needed, a case ends at the next (no `break` needed, no fallthrough), `case a, b:` shares a body, cases at the top of the block only, and every value is handled: every case of an enum with values, every enumerator of a Kelvin enum, or `default:` | `switch (n) { case 1: case 2: ...; break; default: ... }` | `switch n { case 1, 2: ... default: ... }` | 2026-10-10 |
| 64 | `$[T]` is the type `Array<T>`, and `$[[T]]` `Array<Array<T>>`: a `[...]` inside is an Array in turn, as in `$[[1, 0], [0, 1]]` | `struct xs *` | `var va:$[[i64]] = $[[1, 0], [0, 1]]` | 2026-10-10 |
| 65 | `Dictionary<K, V>`, a hash map on the heap, an owner under the rules of #54: `K` an integer type or `String` (the text copied in, read with a cstr or a String), `V` as an Array's element; `$[K: V]` the type, `$[k: v, ...]` and `$[:]` the values; `d[k]` checked, `d[k] = v`, `has`, `find` (a `V^` or nullptr), `get`, `remove`, `clear`, `reserve`, `copy`, `count`; `for k, v in d` and `for k in d`, in the order added | a hash table by hand | `var ages = $["ann": 31]; ages["bob"] = 42; for k, v in ages { }` | 2026-10-10 |
| 66 | `d.keys` and `d.values`: Arrays of copies of a Dictionary's keys and values, in the order added | a loop by hand | `var names = ages.keys` | 2026-10-10 |
| 67 | `` $`a${x}b` ``: a template built as a `String` on the heap, with no bound on its length | `asprintf` | `` var s = $`${name}: ${n}` `` | 2026-10-10 |
| 68 | Slices of an `Array`, a `String` (by codepoint) and a `Bytes`: `xs[lo..<hi]`, `xs[lo...hi]`, `xs[lo...]`, `xs[..<hi]`, `xs[...hi]`, each a new copy, the range checked | `memcpy` of a part | `var ys = xs[1..<3]`, `var t = s[2...]` | 2026-10-10 |
| 69 | A Dictionary's entries are written in braces: `${k: v, ...}`, `${:}` for none, `Dictionary<K, V>({k: v})`; the type stays `$[K: V]` | `{ {"a", 1}, {"b", 2} }` by hand | `var d = ${"ann": 31}` | 2026-10-10 |
| 70 | A Dictionary's type is `${K: V}`, in braces as its entries are; `$[K: V]` says so. Each type's document ends with a synopsis of its properties and methods, and properties.md indexes them | | `var d:${String: i64} = ${:}` | 2026-10-10 |
| 71 | `Set<T>`, a hash set on the heap, a Dictionary with no values, under the rules of #54; `${T}` the type, `${a, b, c}` and `${}` the values; `insert` (also `+=`, and `+= &other`), `has`, `remove`, `union`, `intersection`, `difference`, `clear`, `reserve`, `copy`, `count`, `elements`; `for x in s`, in the order added | a hash set by hand | `var s = ${3, 1, 4}; s += 9; if s.has(4) { }` | 2026-10-10 |
| 72 | `Optional<T>`, or `T?`: a value that may be absent, an enum with values with the cases `none` and `some: T`, made per `T`; a `T` where a `T?` is expected becomes `some`, `none` is the absent value; `x.some` checked, `x ?? y`, `x.is(none)`, `switch` on it | a sentinel, or a bool beside the value | `var x:i64? = none; x = 3; println(x ?? 0)` | 2026-10-10 |
| 73 | `s \| t`, `s & t` and `s ~ t` on Sets: the union, the intersection and the symmetric difference, new Sets; `\|=`, `&=`, `~=` in place | loops by hand | `var u = s \| t; s &= t` | 2026-10-10 |
| 74 | `if let x = e { ... } else { ... }`: binds the value of an Optional or a Result when present, a let it still owns; `e` read once, a variable or a value a call gives | `if (o.tag) { T x = o.u.some; ... }` | `if let v = find(&xs, 7) { println(v) }` | 2026-10-10 |
| 75 | `Result<T, U>`: an enum with values with the cases `ok: T` and `err: U`; a `T` where one is expected becomes `ok`, `ok(v)` and `err(e)` are words there; `r.ok`, `r.err`, `r ?? y`, `if let`, `switch`; `Optional<T>` is its special case, the same machinery with `none` and `some`; `Optional<T>.some(v)`, `.none`, `Result<T, U>.ok(v)`, `.err(e)` | an error code beside the value | `let parse(s:cstr):Result<i64, String> { ... return err($"empty") ... }` | 2026-10-10 |
| 76 | `try r`: the `ok` (`some`) value of a Result (an Optional), or a `return` of its `err` (`none`) from the function, passed up as it is; a prefix, as `-x` is; the function returns a Result whose `err` has the same type, or an Optional; of a place whose value owns, an error; alone, a statement that drops the value | `if (r < 0) return r;` after every call | `let n = try parse(s)`, `return try f(a) + try f(b)` | 2026-10-11 |
| 77 | `return {...}` takes the function's result type, as a declaration's `{...}` does: a struct's or union's, with designators, a C struct's, an enum with values' `{.n = v}`, and the value of a Result or an Optional, wrapped; a number's result still takes a value | `return (struct point){0, 0};` | `let origin():point { return {0, 0} }`, `return {5, 6}` of a `Result<point, cstr>` | 2026-10-11 |
| 78 | `if let err(e) = r { ... } else { ... }`: the case by its name, its value bound to `e` when that is the case, of a Result, an Optional or any enum with values (`if let n(x) = j`); `if let ok(v) = r` spells #74 out; a case with no value has nothing to bind | `if (r.tag == ERR) { ... r.u.err ... }` | `if let err(e) = parse(s) { println(e) }` | 2026-10-11 |
| 79 | `==` and `!=` on a Result, an Optional and an enum with values: the same case, and equal values (a String's by its bytes, a nested one's by its own `==`, a `cstr`'s by its address); a value, `none`, `ok(v)` or `err(e)` on the other side is wrapped, as where one is expected; no `==` where a case's value has none (a struct, an Array); an owner made on the spot is not taken | `a.tag == b.tag && a.u.ok == b.u.ok` by hand | `x == none`, `r == 42`, `r == err(2)`, `a != b` | 2026-10-11 |
| 80 | `x.map(f)`, `x.map { ... }`: a `U?` or a `Result<U, E>` of `f`'s result when the value is there, else the other case carried over; `r.mapErr(g)` a `Result<T, F>` of the err; `f` a function by name, a function value, or an anonymous function whose result kelvinc sees or which writes it; of a variable that owns, an error: map the call, or a copy | `r.tag ? g(r.u.err) : f(r.u.ok)` by hand, into a new struct | `parse(s).map(twice)`, `x.map { $0 > 2 }`, `parse(s).mapErr(code)` | 2026-10-11 |
| 81 | `x.flatMap(f)`: `f` gives the new `U?` or `Result<U, E>` itself, with the same `E`, and `x.flatMap(f)` is that when the value is there, else `none` or the `err` carried over; by name or as a trailing function, chained with `map` | `r.tag ? r : f(r.u.ok)` by hand | `parse(s).flatMap(positive)`, `a.flatMap(half)` | 2026-10-11 |
| 82 | `IO`, stdio as an owner: `IO(path, mode)` a `Result<IO, i32>`, the IO or errno; `IO.stdin`, `IO.stdout`, `IO.stderr`, never closed; `f.bytes` and `f.string` the rest of the file as a Result (EILSEQ for bad UTF-8); `for x in f.read(n)` and `for line in f.lines`; `f.write(text, &s, or an owner given)`, `f.flush()`, `f.close()`; closed when its block ends, moved, borrowed, not copied | `FILE *f = fopen(...); if (!f) ...; fclose(f);` | `let f = try IO(path, "r")`, `for line in f.lines { }` | 2026-10-12 |
| 83 | `f.print(a, b, ...)` and `f.println(...)`: as `print` and `println`, by each value's type, up to 16 values, to an IO | `fprintf(f, "%lld", n)` with the right format per type | `IO.stderr.println("warning: ", n)`, `log.println(x, " ", y)` | 2026-10-12 |
| 84 | an IO's position: `f.eof`, true once a read has met the end; `f.position` and `f.count`, the offset and the length in bytes, -1 where the stream has none; `f.seek(n)` from the start, a `bool`; `f.rewind()` | `feof(f)`, `ftell(f)`, `fseek(f, n, SEEK_SET)`, `rewind(f)` | `f.seek(f.count - 16)`, `for chunk in f.read(4096) { }; if f.eof { }` | 2026-10-12 |
| 85 | reading one at a time from an IO: `f.byte` the next byte, a `u8?`; `f.i64` and `f.f64` the next integer or float as `scanf` reads them, an `i64?` or an `f64?`; `none` at the end, or where no number is there | `fgetc(f)` and `EOF`, `fscanf(f, "%lld", &n) == 1` | `if let n = f.i64 { sum += n }` | 2026-10-12 |
| 86 | `IO(fd, mode)`, with a number first: a file descriptor's IO, as `fdopen` gives it, owned, so its block closes the descriptor; `f.fd` the descriptor, an `i32`, -1 once closed | `FILE *f = fdopen(fd, "r")`, `fileno(f)` | `var f = IO(fd, "r")`, `write(f.fd, p, n)` | 2026-10-12 |
| 87 | `IO.popen(command, mode)`: a shell command's output or input as an IO, a `Result<IO, i32>`; its block or `close()` waits for it, and `f.status` is then its exit code, -1 otherwise; `IO.pipe()`: a `Result<{reader: IO, writer: IO}, i32>`, each end an IO that owns its descriptor | `popen`, `pclose` and `WEXITSTATUS`; `pipe(fds)` and two `fdopen`s | `for line in p.lines { }`, `p.ok.writer.close()` | 2026-10-12 |
| 88 | no `f.i64` or `f.f64`: a number is read from a line, `i64(line)`, or the whole text; `f.byte` stays; the converters take a String as they take a `cstr` | `fscanf(f, "%lld", &n)` | `for line in f.lines { sum += i64(line) }` | 2026-10-12 |
| 89 | `f.signal`: the signal that ended a process, once closed; 0 when it exited on its own; -1 before, or for an IO that is no process; `status` is then -1 for a process a signal ended | `WIFSIGNALED(st) ? WTERMSIG(st) : 0` after `pclose` | `p.ok.close(); if p.ok.signal != 0 { }` | 2026-10-12 |
| 90 | `IO.exec(args, mode)`: a program run without the shell, `args` a list of text or an Array of cstr or of String in a variable, the program found on the PATH; `"r"` reads its output, `"w"` writes its input; a `Result<IO, i32>` with the exec's own errno as the err; waited for when closed, with `status` and `signal` | `pipe`, `fork`, `dup2`, `execvp`, `waitpid`, and a close-on-exec pipe to learn why exec failed | `IO.exec(["wc", "-l", path], "r")` | 2026-10-12 |
| 91 | `f.kill(signal)`: a signal to a process `IO.exec` started, a `bool`, true when sent; `f.pid` its process id, an `i32`, -1 for any other IO, a `popen`'s included, whose child's pid C does not give | `kill(pid, sig)` | `p.kill(SIGTERM)`, `p.close(); p.signal` | 2026-10-12 |
| 92 | `IO.exec(args, mode, dir)` and `IO.exec(args, mode, dir, env)`: the program run in `dir`, text or a String, `""` for the current directory, and with `env`'s `"NAME=value"` entries, a list or an Array of cstr or of String, added to the parent's environment; a directory that cannot be entered is an err | `chdir` and `putenv` in the child before `execvp` | `IO.exec(["make"], "r", "build", ["CC=clang"])` | 2026-10-12 |
| 93 | `IO.exec(args, mode, dir, env, fresh)`: with `fresh` true, the entries are the whole environment, `[]` an empty one, and the program is found on that environment's PATH, or the system's default; false, or absent, adds them to this program's | `environ = envp; execvp(...)` in the child | `IO.exec(["/usr/bin/env"], "r", "", ["ONLY=1"], true)` | 2026-10-12 |
| 94 | `OS` and `SYS`, the prelude's namespaces, no import: `SYS.argv` (an `Array<cstr>`), `SYS.exit(code)`, `SYS.platform`; `OS.cwd` (a `Result<String, i32>`), `OS.chdir`, `OS.env(name)` (a `cstr?`), `OS.setenv`, `OS.unsetenv`, `OS.exists`, `OS.isdir`, `OS.isfile`, `OS.remove`, `OS.rename`, `OS.mkdir`, `OS.rmdir`, `OS.listdir(path)` (a `Result<Array<String>, i32>`, sorted), `OS.system(command)`, `OS.pid`; 0 or `errno` where C only fails; C's `main` always takes `argc` and `argv` | `getcwd`, `getenv`, `stat`, `opendir`, `system`, `exit`, each with its own convention | `if let ok(ns) = OS.listdir(".") { }`, `SYS.exit(2)` | 2026-10-12 |
| 95 | more of `OS`: `stat` and `lstat` as a `Result<{dev, ino, mode, nlink, uid, gid, size, atime, mtime, ctime, isdir, isfile, islink}, i32>`, `islink`, `symlink`, `readlink`, `link`, `unlink`, `chmod`, `truncate`, `makedirs`, `realpath`, `basename`, `dirname`, `join`, `ppid`, `uid`, `gid`, `user`, `host`, `umask`, `kill`, `time`, `sleep`, `tmpdir` | each C's call, `struct stat` read by hand | `OS.stat(p).ok.size`, `OS.join(OS.tmpdir, "x")` | 2026-10-12 |
| 96 | `OS.walk(path)`: every path under a directory, the root left out, each level's names sorted, depth first, links not followed, unreadable directories passed over, a `Result<Array<String>, i32>`; `OS.glob(pattern)`: the paths a shell pattern matches, sorted, the same Result, none where none match | `nftw` or `opendir` by hand; `glob` and `globfree` | `if let ok(ps) = OS.walk(".") { for p in ps { } }`, `OS.glob("*.k")` | 2026-10-12 |
| 97 | `OS.mkstemp(prefix)`: a temporary file made and opened for reading and writing, a `Result<{io: IO, path: String}, i32>`; `OS.mkdtemp(prefix)`: a temporary directory, a `Result<String, i32>`; both in `OS.tmpdir` unless the prefix holds a `/` | `mkstemp` and `fdopen`, `mkdtemp`, with a template of six X | `var t = OS.mkstemp("kelvin_")`, `t.ok.io.println(...)`, `OS.remove(t.ok.path)` | 2026-10-12 |
| 98 | `OS.utime(path, atime, mtime)`: a file's times, in seconds since the epoch as `stat` gives them, a fraction allowed; `OS.touch(path)`: both now, and the file made when missing; each 0 or `errno` | `utimensat`, and `open(O_CREAT)` | `OS.utime(p, OS.time, OS.time)`, `OS.touch("stamp")` | 2026-10-12 |
| 99 | `OS.chown(path, uid, gid)` and `OS.lchown`, a file's owner and a link's own, -1 to leave an id, 0 or `errno`; `OS.username(uid)` and `OS.groupname(gid)`, the names of ids, each a `String?`, and `OS.user` a `String?` too | `chown`, `lchown`, `getpwuid`, `getgrgid` | `OS.chown(p, OS.uid, -1)`, `OS.username(s.ok.uid)` | 2026-10-12 |
| 100 | `IO.popen` runs `/bin/sh -c command` through the fork and exec of `IO.exec`, so its pid is known: `f.pid` and `f.kill(signal)` work on it as on an `IO.exec`'s process | `popen`, whose child's pid C keeps to itself | `var p = IO.popen("sleep 30", "r"); p.ok.kill(SIGTERM)` | 2026-10-12 |
| 101 | an IO keeps its path: `f.path` as given, `f.abspath`, `f.basename`, `f.dirname`, `f.join(name)`; `f.stat` of the open file, `f.lstat`, `f.isdir`, `f.isfile`, `f.islink`, `f.exists`; `f.listdir`, `f.walk`, `f.glob(pattern)`; `f.chmod`, `f.chown`, `f.truncate` on the open file, `f.remove()`, `f.rename(to)` (the path follows; a var), `f.utime`, `f.touch()`; `IO(path)` alone opens for reading | `fstat`, `fchmod`, `fchown`, `ftruncate` on `fileno`, and the path's calls by hand | `let d = try IO("."); for n in try d.listdir { }` | 2026-10-12 |
| 102 | the rest of Python's `os` that C gives plainly: `OS.strerror(code)`, `OS.environ`, `OS.euid`, `OS.egid`, `OS.groups`, `OS.uname`, `OS.readable`, `OS.writable`, `OS.executable`, `OS.isabs`, `OS.splitext`, `OS.normpath`, `OS.relpath`, `OS.expanduser`, `OS.samefile`, `OS.mkfifo`, `OS.sync()`, `OS.cpus`, `OS.loadavg`, `OS.urandom(n)`, `OS.isatty(fd)`, `OS.terminalsize`, `OS.diskusage`, `OS.sep`, `OS.linesep`, `OS.devnull`, `OS.name` | each C's call | `println(OS.strerror(r.err))`, `OS.uname.ok.machine`, `OS.normpath("a/../b")` | 2026-10-13 |
| 103 | `f.isatty`, whether an IO's descriptor is a terminal; `IO.strerror(code)`, the message for an err, a `String`, as `OS.strerror` is | `isatty(fileno(f))`, `strerror(e)` | `if IO.stdout.isatty { }`, `var why = IO.strerror(r.err)` | 2026-10-13 |
| 104 | An open file's attributes straight, no Result: `f.stat` and `f.lstat` give a `Stat`, `f.abspath` a `String`, since the open descriptor always answers; `f.isdir` and `f.isfile` are the open file's. `OS.stat(path)` and the rest of `OS` stay Results: a path is looked up anew at each call | `fstat(fileno(f), &st)` | `let s = f.stat`, `println(f.stat.size, " ", f.abspath)` | 2026-10-13 |
| 105 | `f.abspath` of the open descriptor where the path is gone or there is none: a file renamed behind the IO answers by its new name, a removed one by the name it had; `""` where neither the path nor the descriptor answers | `fcntl(fd, F_GETPATH, buf)`, `readlink("/proc/self/fd/N")` | `OS.remove(f.path); var p = f.abspath` | 2026-10-13 |
| 106 | The rest of an IO's attributes straight: `f.listdir`, `f.walk` and `f.glob(pattern)` give an `Array<String>`, no Result, of the path while it is there, else of the descriptor's name; none where the IO is no readable directory | `opendir(path)` after `fopen` | `var names = d.listdir; for n in names { }` | 2026-10-13 |
| 107 | `f.bytes` and `f.string` straight: the rest of the file as a `Bytes` and as a `String`, no Result, since the file was there to open; text that is not UTF-8 ends `f.string` with a message, as a line of `f.lines` does | `fread` in a loop | `let s = f.string`, `let b = f.bytes; if b.isUTF8 { }` | 2026-10-13 |
| 108 | An IO's operations straight: `f.chmod`, `f.chown`, `f.truncate`, `f.utime`, `f.touch`, `f.remove` and `f.rename` give a `bool`, true when done, no `errno`, as `seek` and `kill` do; through the descriptor where the system can, so they work on a file renamed or removed behind the IO | `fchmod(fileno(f), m) == 0` | `if f.chmod(0644) { }`, `f.touch()` | 2026-10-13 |
| 109 | `IO(path, mode)` and `IO(fd, mode)` straight: the IO, with `f.error` the `errno` when it did not open, 0 otherwise; such an IO is as a closed one, its path kept, and reading it by `f.lines` or writing to it ends the program with the reason. `IO.popen`, `IO.exec` and `IO.pipe()` stay Results for now | `FILE *f = fopen(p, m); if (!f) return errno;` | `let f = IO(path); if f.error != 0 { return err(f.error) }` | 2026-10-14 |
| 110 | `IO.popen`, `IO.exec` and `IO.pipe()` straight: the IO, with `f.error` the `errno` when the process could not start, `ENOENT` for a program not found; the pair `{reader: IO, writer: IO}`, both ends carrying the error of a pipe not made | `popen(cmd, "r")`, `pipe(fds)` | `var p = IO.exec(["ls"], "r"); if p.error == 0 { for line in p.lines { } }` | 2026-10-14 |
| 111 | Functions of a type: `static let T.name(params):R { }`, Swift's `static func`, with no self, called as `T.name(args)`; `T` a struct, union or enum with values of the program; overloads by parameter types as any function's | a function named `T__name` | `static let point.of(x:i64, y:i64):point { (point){x, y} }`, `let p = point.of(3, 4)` | 2026-10-14 |
| 112 | `#import <name>` with no extension is `#import <name.k>`: a Kelvin file of `./modules` or of Kelvin's `modules/` | — | `#import <JSON>` | 2026-10-14 |
| 113 | `modules/JSON.k`: `enum JSON { null; boolean: bool; number: f64; string: String; array: Array<JSON>; object: Dictionary<String, JSON>; error: String }`, `JSON.parse(text)` of a cstr or a borrowed String, straight, with a text that is not JSON as the case `error`, and `JSON.stringify(&j, replacer, space)` as JS's, numbers written as JS writes them | a JSON library | `var j = JSON.parse(text); println(j.object["k"].number); var s = JSON.stringify(&j, "  ")` | 2026-10-14 |
| 114 | An anonymous function with an Optional result, `{ (v:i64):i64? in ... }`: the `?` before `in` is the type's, and a one-expression body is wrapped as `return` wraps it, a `U` or `none` of a `U?` | — | `xs.map { (v:i64):i64? in v > 2 ? Optional<i64>(v) : none }` | 2026-10-14 |
| 115 | `"""text"""`: a string literal over any number of lines, with the text as written, no escapes, no `${...}`, a `cstr` as any literal; `$"""..."""` a String of it | `"line\n" "line\n"` | `JSON.parse("""{"a": "b\n"}""")` | 2026-10-14 |
| 116 | `none` as an arm of `?:`: where a `T?` or a Result is expected, each arm is wrapped on its own, `return c ? v : none`, `c ? ok(v) : err(e)`; beside an arm that is one, `c ? Optional<i64>(n) : none`, the other is wrapped to it; an else arm `Optional<i64>(n)` or `Bytes(s)` is a value, not an annotation | `c ? a : b` | `let half(v:i64):i64? { v % 2 == 0 ? v / 2 : none }` | 2026-10-14 |
| 117 | `v[k]` of an enum with values: through its Dictionary case with text, its Array case with an integer, checked as the case and the index are; so `j["key"]` and `j[i]` on a JSON, a place, a path | — | `j["tags"][1].number`, `j["n"] = JSON.number(4.0)` | 2026-10-14 |
| 118 | `"""` on its own lines: the line break after the opening run and the one before the closing run are not text, and the closing run's indentation comes off each line; a longer delimiter, `""""`, holds a `"""`, closed by a run as long, the extra quotes of a longer closing run being text | — | `let doc := """` ... `"""` | 2026-10-14 |
| 119 | `switch v { case n(x): ... }`: the case's value bound to `x`, a let the enum still owns, for that case's body, as `if let n(x) = v` binds it; a binding case stands alone; a value no place holds is read once | — | `switch r { case ok(v): println(v) case err(e): println(e) }` | 2026-10-14 |
| 120 | An enum with values and no tag at the top level, `enum { red; rgb: {r: u8, g: u8, b: u8} }`: the type of its spelling, and its cases words of the program, `red` a value and `rgb({1, 2, 3})` a maker, as C's anonymous enum declares its enumerators; a case named `ok`, `err`, `none`, `some`, a function or an enumerator is an error | `enum { A, B }` declaring A and B | `var c = rgb({1, 2, 3})` | 2026-10-14 |
| 121 | Methods and operators on a type with no tag, by its spelling: `let enum{nothing, just: i64}.orZero():i64 { }`, `let {x: f64, y: f64}.norm2():f64 { }`, `let +(a:enum{...}, b:enum{...}):enum{...}`; and an operator of any enum with values is the program's, `==` and `!=` included once written | functions named by the record | `just(3).orZero()`, `just(1) + just(2)` | 2026-10-14 |
| 122 | `print`, `println`, `f.print` and `f.println` show a struct, a union or an enum with values that kelvinc sees as its `.cstr` text, the derived one or the type's own `T.cstr()`, as a template does | — | `println(p)` | 2026-10-14 |
| 123 | `print`, `println` and `f.println` show a value with brackets whole, on one line, by a printer kelvinc writes for each type: a struct `{x: 1}`, an enum with values `n(v)`, an Optional, a Result, an `Array` `[a, b]`, a `Dictionary` `{"k": v}`, a `Set` `{a, b}`; a `String`, a `Bytes` or a `cstr` inside a value is quoted and escaped, also in `.cstr` and `${v}`, which stay cut to their room | a loop of `printf`s | `println(xs, " ", ages)` | 2026-10-14 |
| 124 | `v.pretty`: the same text indented, each item of a `[]` or `{}` on a line of its own, two spaces a level; printed where `print` shows it, a `String` elsewhere | — | `println(cfg.pretty)`, `var text = cfg.pretty` | 2026-10-14 |
| 125 | `${xs}` of an Array, a Dictionary or a Set in a template: its text by kelvinc's printer (#123), cut to a template's room as a string value is, and whole in `` $`...` ``; one an expression gives is bound first | — | `` `xs = ${xs}` ``, `` $`${d}` `` | 2026-10-14 |
| 126 | `${v.pretty}` in a template: the value's text indented, by kelvinc's printer, cut to a template's room as a string value is, and whole in `` $`...` `` | — | `` `cfg = ${cfg.pretty}` `` | 2026-10-14 |
| 127 | `x.pretty(n)`: `n` spaces a level, an integer from 0 to 10, as JS clamps `JSON.stringify`'s space; `x.pretty` stays two; a literal out of range is an error, a computed one clamped | — | `println(cfg.pretty(4))` | 2026-10-15 |
| 128 | `x += y` on an enum with values by the operator the program defines, `x = x + y`, as for a struct (#42); and `x = v` of a struct or an enum that owns evaluates `v` before it frees what `x` held, so `x = x + y` and `x = f(x)` keep `x`'s value | — | `t += txt.s($"cd")` | 2026-10-15 |
| 129 | `JSON.stringify(&j, n)` and `JSON.stringify(&j, replacer, n)`: a number as the space, that many spaces a level, 0 to 10, as JS's takes one and as `v.pretty(n)` indents; 0 is compact | `JSON.stringify(v, null, 4)` in JS | `JSON.stringify(&j, 4)` | 2026-10-15 |
| 130 | `extend T { }`, Swift's `extension`: the members of `T` without writing `T` each time, `let f()` a method, `static let f()` a function of the type, and the attributes of #131 to #133; of a type of the program, a built-in one, or one with no tag by its spelling | functions on `struct T *` | `extend rect { let area:f64 { ... } }` | 2026-10-15 |
| 131 | `let T.x:R { }`, or `let x:R { }` in extend: a computed attribute, read as `v.x` with no parentheses, its body a method's; `v.x()` and `v.x = y` are errors; a member of the same name is an error | a getter function | `r.area` | 2026-10-15 |
| 132 | `var T.x:R { get { } set(v) { } }`, or in extend: a computed attribute with a setter; `v.x = y` and `v.x += y` call the setter on the var that holds `v`, whose `self` is that var | a getter and a setter on `struct T *` | `t.celsius = 100.0` | 2026-10-15 |
| 133 | `static let T.x = v` and `static var T.x = v`, or in extend: type attributes, a global of the type read and written as `T.x`; a `static let` needs its value; a type with no tag has none | a global `T_x` | `rect.made += 1` | 2026-10-15 |
| 134 | `x.m = v`, `xs[i].m = v` and `p^ = v` of a type that owns free what they held, after the new value is made, as `x = v` of a local does | — | `p.name = $"Grace"` | 2026-10-15 |
| 135 | Operators in `extend T { }`: `static let +(a:T, b:T):T { }`, as Swift's `static func +`, the same as the top level's `let +`; one of its values is a `T`; a plain `let +` in extend is an error naming `static` | — | `extend money { static let +(a:money, b:money):money { ... } }` | 2026-10-15 |
| 136 | Subscripts: `let [](i:I):R { }` in `extend T { }`, alone `let T[](i:I):R { }`, read as `v[i]`; `var [](i:I):R { get { } set(v) { } }` also written as `v[i] = y` and `v[i] += y` on the var that holds `v`; several indices read `v[r, c]`, and subscripts overload by the indices' count and types; one of an enum with values wins over #117 | — | `extend grid { var [](r:i64, c:i64):i64 { get { ... } set(v) { ... } } }`, `g[1, 2] = 7` | 2026-10-15 |
| 137 | A getter's `self` is a `let`: a `let` attribute and a `var` attribute's `get { }` read `self` and never change it, so `self.n += 1` or `self = v` there is an error naming the setter, and `self` is `const` in C, as any `let` is (#27); a method is unchanged | — | `let counter.next:i64 { self.n += 1 }` is an error | 2026-10-15 |
| 138 | A method's `self` is a `let`, as a getter's (#137): `self.x += 1` or `self = v` in a method is an error that names a setter and `T^`, and `self` is `const` in C; a copy, `var p = self`, changes. This replaces #27's "self is a mutable copy" | — | `let point.moved(dx:i64):point { var p = self; p.x += dx; return p }` | 2026-10-15 |
| 139 | `.x` is `self.x` in every body that has `self`: a method, an attribute, a setter, a subscript; in an initializer `.x = v` is still a designator and `.x` alone is `self.x`; a new line that sets a member, `.n = v`, starts a statement there, while any other `.member` on a new line goes on with the expression (#35) | — | `let area:f64 { .w * .h }`, `set(v) { .kelvin = v + 273.15 }` | 2026-10-15 |
| 140 | `Self` is the receiver's type, as Swift's: inside `extend T { }` and in a method, an attribute, a subscript or a function of `T` written alone, where a type goes and where `T`'s name goes, `Self.f()`, `Self.x`, `Self(v)`; a type with no tag has no name, so its `Self` is a type only; elsewhere `Self` is an error that says where it belongs | — | `extend point { let moved(dx:i64):Self { var p:Self = self; ... } }` | 2026-10-15 |
| 141 | `:()` after the parameters says a function gives nothing, C's `void`, written out: on a function, a prototype, a method, an anonymous function and in a function type, `(i64):()`; `:():R` stays a function type as the result | — | `let greet(name:cstr):() { println("hi ", name) }` | 2026-10-15 |
| 142 | Where there is `self`, a line that starts with `.x` is `self.x`, a statement of its own, whatever follows; a chain over several lines goes inside parentheses there, or on one line; where there is no `self`, a `.member` on a new line goes on with the expression before it (#35). This widens #139's rule, which started a statement only where the line set a member | — | `let k = 10` then `return .is(just) ? .just + k : k` on the next line | 2026-10-15 |
| 143 | A module as a header and a library, like C's: `M.kh`, a Kelvin file of declarations, and `libkM.a` (or a shared `libkM`) beside it in `modules/`; `#import <M>` looks for `M.kh` before `M.k`, in `./modules` then Kelvin's `modules/`, brings the header in and links the library by itself, before `libkelvin`, in the order imported; a `.kh` with no library is a header alone | — | `#import <IO>` reads `modules/IO.kh` and links `modules/libkIO.a` | 2026-10-16 |
| 144 | `IO` is a module, `#import <IO>`: `modules/IO.kh`, the C header `kIO.h` and `libkIO`, built from runtime/io.c, out of the prelude; without the import `IO` is an error that says to write it; `IO.kh` imports `<OS>`, which IO's path functions use | — | `#import <IO>` then `let f = IO(path, "r")` | 2026-10-16 |
| 145 | `OS` with `SYS` is a module, `#import <OS>`: `modules/OS.kh`, `kOS.h` and `libkOS`, built from runtime/os.c, out of the prelude; without the import `OS` and `SYS` are errors that say to write it, and `OS.mkstemp`, which gives an IO, asks for `#import <IO>`; a program that does not import it has no `kv_sys_init` in its `main` | — | `#import <OS>` then `var args = SYS.argv` | 2026-10-16 |
| 146 | `kelvinc --lib M.k` builds a Kelvin file into a module: `M.kh`, its declarations with the bodies dropped, and `libkM.a`, in `./modules` or the directory `-o` names; the header holds the imports, the types whole, a prototype of each function, method, function of the type, operator, attribute and subscript in their `extend` blocks, `extern let x:T` for a global, `extern let` for a C function's prototype, and `T.cstr()` with its body; a file's `static let` is left out, a type attribute waits, and `main` is an error. In a `.kh`, a prototype without `extern` is the library's, named by its types, and attributes and subscripts may be prototypes | — | `kelvinc --lib geo.k`, then `#import <geo>` | 2026-10-16 |
| 147 | `kelvinc --lib M.k` makes the shared library too, `libkM.dylib` on macOS and `libkM.so` elsewhere, beside `libkM.a`: the same object, linked against the shared `libkelvin` and the shared libraries of the modules the file imports, or their static ones where there is no shared one, for C and other toolchains; `#import <M>` links the static one | — | `kelvinc --lib geo.k`, then `cc geo_c.c modules/libkgeo.dylib -Wl,-rpath,...` | 2026-10-16 |
| 148 | `modules/complex.k` is `modules/math.k`, `#import <math>`: math.h and its complex counterpart, as C's math and cmath. The functions of math.h for `f64`, C's own declared, and for `f32`, their `f` kind; each a method too, `x.sin()`, `x.pow(y)`; the constants as attributes of the type, `f64.pi`, `tau`, `e`, `ln2`, `ln10`, `log2e`, `log10e`, `sqrt2`, `infinity`, `nan`, `epsilon`, `max`, `min`, and of `f32`; `x.isnan`, `x.isinf`, `x.isfinite`; the complex functions as methods, `z.exp()`, `z.pow(w)`; `x.i`, `x` rotated a quarter turn: `1.0.i` is `complex64(0.0, 1.0)`, `z.i` is `z` times i; `abs` of a float and of an `i64`. A type attribute may be of a number type, `static let f64.pi:f64 = ...`, read as `f64.pi`, and a module's header declares one as `static let T.x:R` | — | `f64.pi.sin()`, `2.0.sqrt()`, `(0.5:f32).sin()`, `1.0.i.i` | 2026-10-16 |
| 149 | `typealias A = T`, Swift's, at the top level: from there on `A` is `T` wherever a name is read, as a type, before a dot, as a converter, as an `extend`'s; `T` is a struct, union or enum with values declared before it, or a built-in type, and `A` a new name; a module's header keeps the line | — | `typealias real = f64`, `typealias pt = point`, then `pt.of(1, 2)`, `real.pi` | 2026-10-16 |
| 150 | `complex64` and `complex32` are `c64` and `c32`, named by the size of each part, in `modules/math.k`; `typealias complex64 = c64` and `typealias complex32 = c32` there keep the old names, so `complex64(1.0, 2.0)` is `c64(1.0, 2.0)`; `.typename` is `c64` | — | `let z:complex64 = c64(1.0, 2.0)` | 2026-10-16 |
| 151 | The number types have full names: `int8` ... `int128` are `i8` ... `i128`, `uint8` ... `uint128` `u8` ... `u128`, `float32` and `float64` `f32` and `f64`, each the keyword by another name wherever the short one goes; `.typename` is the short one | — | `var n:int64 = 5`, `float64(3)`, `uint8(c)`, `float64.pi` | 2026-10-16 |
| 152 | `#import <SION>`: `enum SION { nil; boolean: bool; integer: i64; number: f64; string: String; data: Bytes; date: f64; ext: Bytes; array: Array<SION>; dictionary: Array<SION>; error: String }`, a dictionary its keys and values in turn, keyed by any value; `SION.parse(text)` reads SION's text, integers in four bases, doubles with hex floats, nan and inf, Swift's escapes, `.Data`, `.Ext`, `.Date`, `[:]`, trailing commas and `//` comments; `SION.stringify(&s, space)` writes doubles as `%a`; `s["key"]` and `s[i]` give copies and set; `SION.same`, `SION.find`, `s.count` | — | `SION.parse("[0: nil, \"pi\": 0x1.921fb54442d18p+1]")` | 2026-10-16 |
| 153 | `#import <MsgPack>`: `MsgPack.pack(&s)` packs a `SION` into MessagePack in each value's smallest form, a date as timestamp 64 or 96, an ext as its whole encoding kept; `MsgPack.unpack(&b)` reads every format, uints and float 32 included, timestamps as dates, other exts as exts, with `error` for bytes that are not MessagePack and an uint 64 past an `i64` | — | `MsgPack.unpack(&MsgPack.pack(&s))` is `s` | 2026-10-16 |
| 154 | Reading a case's value, `v.n`, or an attribute, `v.x`, of an owner that an expression gives is an error that says to bind it first, as `.is` and `.case` were (#99): the copy would be lost with what it holds | — | `s["a"].string` is an error; `var a = s["a"]`, then `a.string` | 2026-10-16 |
| 155 | Base64 in the prelude: `b.toBase64()` gives a String, standard and padded, and the words `url` and `nopad`, in either order, pick the URL-safe alphabet and no padding; `Bytes.fromBase64(text)` takes a `cstr` or a String borrowed, `&s`, either alphabet, with or without padding, blanks skipped, and a letter that is neither ends the program | — | `b.toBase64(url, nopad)`, `Bytes.fromBase64("TWFu")` | 2026-10-16 |
| 156 | `#import <UnicodeData>`, the Unicode Character Database as a module written in Kelvin over C tables (Unicode 18.0.0, from tools/ucd/): `s.normalize(nfc)`, `nfd`, `nfkc`, `nfkd`, the words of `enum NormalForm`; `s.graphemes`, the grapheme clusters, an `Array<String>`; `s.upper()`, `s.lower()`, `s.fold()`, the simple case mappings; a `uchr`'s `.name`, `.category`, `.isLetter` and the other classes, `.combining`, `.upper`, `.lower`, `.fold`, `.decomposition`, `.compatibility`. A method of the program on an owner that an expression gives is an error, bind it first; `kelvinc --lib M.k x.o` adds objects to the library; a user method on a String or a Bytes comes before the built-in ones | — | `s.normalize(nfc)`, `var gs = s.graphemes`, `uchr("é").name` | 2026-10-17 |
| 157 | `#import <RegExp>`, regular expressions, JS's with the u flag, over Strings by codepoint, a module written in Kelvin over a C engine on UnicodeData: `$/pattern/flags`, a literal that is `RegExp.compile("pattern", "flags")` and so needs the import; the flags gimsyud; groups, named groups, lazy and counted quantifiers, classes, `\d\w\s`, `\p{...}` by General_Category, Script, Script_Extensions and the binary properties, backreferences, lookahead and lookbehind, `(?ims-ims:...)` modifiers, and `\X`, a grapheme cluster; `re.test(&s)`, `re.exec(&s)`, `re.execFrom(&s, from)`, `re.search(&s)`, `s.match(&re)`, `s.replace(&re, with)`, `s.split(&re)`, a `Match` with `m.text[i]`, `m[i]`, `m["name"]`, `m.start`, `m.end`, `m.has(i)`; a borrow of an owner an expression gives is an error | — | `let re = $/(\d+)-(?<m>\d\d)/g`, `s.replace(&re, "$<m>/$1")` | 2026-10-17 |
| 158 | Methods overload by their parameter types, as functions do (#41): `let box.add(n:int64)` and `let box.add(t:cstr)`, the call choosing by its arguments, an anonymous argument taking the type of the overload with a function there; in C the overloads are named by their types. An owner given by value moves into a method, and into a call through a function value, `f(b)`, which frees it (O5). `String(n)` of a number or a bool is its text. `s.replace(&re) { ... }` of RegExp takes a function of the Match | — | `s.replace(&re) { String(f64($0.text[0]) * 2.0) }` | 2026-10-17 |
| 159 | `s.match(&re) { ... }` and `re.match(&s) { ... }` of RegExp call a function, `(Match):()`, with each match, every one with the g flag and the first alone without, the Match owned by the function, as `s.match(&re)` gives them in an Array | — | `s.match(&temp) { println($0.text[1], " at ", $0.start) }` | 2026-10-17 |
| 160 | `s.split(&re) { ... }` and `re.split(&s) { ... }` of RegExp call a function, `(String):()`, with each piece of the text cut at the matches, the pieces that `s.split(&re)` gives in an Array, each owned by the function | — | `s.split(&blanks) { println($0) }` | 2026-10-17 |
| 161 | `s.replace(&re, &with)` and `re.replace(&s, &with)` of RegExp take the replacement as a String borrowed, beside the `cstr` form, an overload by its type | — | `s.replace(&re, &tpl)` | 2026-10-17 |
| 162 | `RegExp(pattern, flags)` makes a RegExp, as `RegExp.compile` does, the pattern and the flags each a `cstr` or a String borrowed, `&s`: functions named as the type is, as `c64(...)` are; a type's `T.name(...)` and `T.x` are read where a function is named as the type | — | `let re = RegExp(&pattern, &flags)` | 2026-10-17 |
| 163 | A `$/.../` literal is checked as kelvinc reads it: a pattern that is not JS's, a `\p{...}` name there is none of, or a flag that is none, is an error at its place in the pattern, before anything runs; `RegExp.compile` of text checks at run time as before | — | `$/(a/` is an error at the `(` | 2026-10-17 |
| 164 | `s.escape()` of the prelude gives the text with each codepoint beyond ASCII as `\u{...}` and a `\` as `\\`; `s.unescape()` reads those back, and `\uHHHH`, `\xHH`, `\n`, `\r`, `\t`, `\0`, `\"` and `\'` too, leaving what is none as written; with `<RegExp>`, `s.escape(&re)` and `s.escape($/.../)` escape what the pattern matches instead, the literal moved in. A call with no argument of a method the program overloads only with arguments is the built-in one | — | `s.escape($/[\p{Emoji}]/)` | 2026-10-17 |
| 165 | `s.unescape(&re)` and `s.unescape($/.../)` of RegExp read back the escapes in what the pattern matches alone, each match as `s.unescape()` reads the whole, the rest as it is | — | `e.unescape($/\\u\{1F[0-9A-F]+\}/g)` | 2026-10-17 |
| 166 | `b.escape()` of a Bytes gives its bytes as text, a String: each that is not printable ASCII, below a space, DEL and above, as `\xHH`, and a `\` as `\\`; `s.unescape()` reads it back where the bytes were text | — | `Bytes("a\tb").escape()` is `a\x09b` | 2026-10-17 |
| 167 | `Bytes.unescape(text)`, of a `cstr` or a String borrowed, `&s`, gives the bytes the escapes stand for: `\xHH` a byte, `\u{...}` and `\uHHHH`, a surrogate pair joined, the UTF-8 of the codepoint, `\n`, `\r`, `\t`, `\0`, `\\`, `\"` and `\'` theirs, and what is none as written; `b.escape()` read back | — | `Bytes.unescape(&e) == b` | 2026-10-17 |
| 168 | A RegExp on a Bytes: `b.escape(&re)` and `b.escape($/.../)` give the bytes as text, each byte the pattern matches as `\xHH`, the Bytes matched byte by byte, each byte the codepoint of its value, and every byte that is not printable ASCII escaped too, a String holding text; `Bytes.unescape(text, &re)`, text a `cstr` or `&s`, the pattern borrowed or a literal moved in, reads the escapes back into bytes where the pattern matches the text alone. A function of a type may be declared on `Bytes` or `String` in an `extend`; an attribute of a type is not read on a value of another type kelvinc sees | — | `b.escape($/[\x80-\xFF]/g)`, `Bytes.unescape(&s, &re)` | 2026-10-17 |
| 169 | `b.test(&re)`, `b.search(&re)`, `b.match(&re)` and `b.split(&re)` on a Bytes, and `re.test(&b)` and the rest on the RegExp, as a String has them, the Bytes matched byte by byte: a `BytesMatch` holds the bytes of the whole and of each group, `m.data[i]`, with their byte offsets, `m[i]` and `m["name"]` copies; `split` gives Bytes; `b.match(&re) { }` and `b.split(&re) { }` call a function with each | — | `b.match(&pair) { print($0.start, " ") }` | 2026-10-17 |
| 170 | `b.replace(&re, &with)` and `b.replace(&re, text)` on a Bytes, and on the RegExp with `&b`, give the Bytes with each match replaced, all with the g flag and the first alone without, the replacement a Bytes borrowed or a `cstr` with `$&`, `$1`, `$<name>`, `` $` ``, `$'` and `$$` over bytes; `b.replace(&re) { ... }` takes a function `(BytesMatch):Bytes` | — | `b.replace(&pair, &with)`, `b.replace(&pair) { $0[1] }` | 2026-10-17 |
| 171 | The `b` flag of a RegExp, Kelvin's: binary, each character a byte of its value, on a Bytes and on a String's UTF-8 alike, so that `$/[\x80-\xff]/b` matches one byte where `$/[\u0080-\u00ff]/` matches a codepoint; without it a character is a codepoint, a Bytes read as UTF-8 as far as it is, which the `u` flag says and changes nothing; `re.binary` and `re.unicode` | — | `b.escape($/[\x80-\xff]/gb)` | 2026-10-17 |
| 172 | `Bytes([...])` is a Bytes of the bytes written out, each a character constant, a number 0 to 255 or any `u8` value, a number out of that range an error, `Bytes([])` empty. The document of `Bytes` is bytes.md, apart from strings.md, which keeps `cstr`, `String` and `uchr`: alike to look at, another thing | — | `Bytes([0x89, 'P', 'N', 'G'])` | 2026-10-17 |
| 173 | documents/README.md lists the documents, one line each, in the order a reader might take them: starting, values, reading and writing, modules; the README points to it | — | documents/README.md | 2026-10-18 |
| 174 | A check that fails at run time prints its reason and exits with status 1, stdout flushed first, where it aborted: an index past the count, text that is not UTF-8, a pattern that is not one, a file that will not open where that is checked, out of memory; `KELVIN_ABORT` set in the environment makes it abort instead, for a debugger or a core. A run test may expect a status, `// exit: N`, and stderr, `// err:` lines | — | `kelvin: index 3 is out of range: the Bytes has 3`, status 1 | 2026-10-18 |
| 175 | tests/asan.sh, `make asan`: every program of tests/run, with the runtime and the modules, compiled with AddressSanitizer and a counting allocator, tests/asan/count.c, and run: an ASan error, an unexpected status, or a block still live at exit fails it, a leak the ownership rules should have freed; a test that expects another status is run for ASan alone; a CI job runs it | — | `make asan` | 2026-10-18 |
| 176 | tests/docs.sh, run by `make test`: every ```kelvin block of the documents and the README compiles, a block with `let main(` as it is, any other with its declarations at the margin kept at the top level and the rest wrapped in a main; a listing or a sketch has `<!-- fragment -->` on the line before its fence, which the page does not show | — | `make test` | 2026-10-18 |
| 177 | On a String: `s.find(text)`, the codepoint index of the first `text` or -1, `s.has(text)`, `s.starts(text)` and `s.ends(text)`, the text a `cstr` or a String borrowed, `&t`, a String by value an error; `s.trim()`, a new String without the blanks at either end, JS's `\s` | — | `s.find("llo")`, `s.has(&t)`, `s.trim()` | 2026-10-18 |
| 178 | A global owner with an initializer is an error of kelvinc's, not C's: C initializes a global with a constant alone, and an owner is made by a call; the message says to declare it with its type, `var log:String`, empty, and give it its value in main or another function | — | `var log:String` at the top, `log = $"..."` in main | 2026-10-18 |
| 179 | A method or an attribute of the program is found on a value of its own type: a value whose type kelvinc sees as a pointer, an array or a function has none, so a struct's `count`, `has` or `isNull` cannot catch the built-in one of a `cstr`, an array or a pointer; the fallback to the only method of a name stays for a value whose type kelvinc cannot see. 5000 mutated sources crashed and hung nothing | — | `text.count` of a `cstr` beside `extend tally { let count:int64 }` | 2026-10-18 |
| 180 | A function may be defined inside a function, `let fib(n:int64):int64 { ... }` in a body: a function of the program as one at the top level is, in C a static function `_kv_outer_name` written before the function around it, calling itself, other functions and the globals; its name is the block's, hiding one outside and gone at the block's end; it sees its parameters, not the locals around it, as an anonymous function does not; it has a body | — | `let fib(n:int64):int64 { n < 2 ? n : fib(n - 2) + fib(n - 1) }` in main | 2026-10-18 |
| 181 | `$(...)` calls the function it is written in, as JS's `arguments.callee`: a function at the top level, one inside a function, an anonymous one, or a function of a type, with the function's own arguments in number and type and the owner rules of any call; in a method or an attribute it is an error that says to write `self.name(...)` | — | `let fib(n:int64):int64 { n < 2 ? n : $(n - 2) + $(n - 1) }` | 2026-10-18 |
| 182 | `xs.map(f)` and `xs.map { ... }` of an Array: a new `Array<U>` of `f` of each element, `U` whatever `f` gives, an owner too; an owner element is given to `f` as a copy, which `f` owns, and `xs` stays; the Array is a place. A `.map` function's result, an Array's or an Optional's, is inferred from arithmetic too where its operands are of one number type, or that type and a literal, `$0 * 2` of an `int64`; elsewhere arithmetic still infers nothing. `Array<T>(...)`, `Dictionary` and `Set` makers may start a statement | — | `var doubled = xs.map { $0 * 2 }` | 2026-10-19 |
| 183 | `s + t` on a String is a new String of the two, either side a String, text or a `uchr`, one a String: a String in a variable copied and kept, one an expression gives taken, so that `s + t + u` frees what it made; a number is refused, with a template to show it. `.map` of an Array an expression gives maps it and frees it, so that maps chain | — | `xs.map{ $\`${$0}\` }.map{ $0 + $"+" }` | 2026-10-19 |
| 184 | `xs.filter(f)` and `xs.filter { ... }` of an Array: a new `Array<T>` of the elements `f` says true for, `f` giving a bool; `xs.reduce(init, f)` and `xs.reduce(init) { ... }`: the value of `f` of the value so far and each element, from `init`, of `init`'s type, an owner `init` moved in; both give an owner element to `f` as a copy and take an Array an expression gives, as `map` does | — | `xs.filter { $0 > 1 }.reduce(1) { $0 * $1 }` | 2026-10-19 |
| 185 | `xs.sort()` sorts a var Array in place and `xs.sorted()` gives a new one, each with an optional comparator, `{ $0 < $1 }` or `(T, T):bool`, true where the first goes before the second, else by `<`: a number's, a `uchr`'s codepoint, the bytes of a String, a Bytes or a `cstr`, or a struct's own operator `<`, and an element with none a compile error; a stable merge sort; `.sorted()` of an Array an expression gives sorts it in place. `<`, `<=`, `>`, `>=` on two Strings or two Bytes, by their bytes | — | `$[3, 2, 1, 0].sorted{ $0 < $1 }` is `[0, 1, 2, 3]` | 2026-10-19 |
| 186 | `xs.reverse()` reverses a var Array in place and `xs.reversed()` gives a new one, the elements in the other order, moved as they are; `.reversed()` of an Array an expression gives reverses that one, so that it chains | — | `$[3, 1, 2].sorted().reversed()` is `[3, 2, 1]` | 2026-10-19 |
| 187 | An owner an expression gives is held where it is used, in a hidden local freed once the postfix chain, the comparison or the loop around it is done: a method, an attribute, a property, a subscript, a slice, a case, `.is`, a member, `println` and a template's value, a conversion, `==` and the orderings, the left of `??`, and `for x in`; a member that owns is copied out, and one given where a borrow `const T^` is taken is lent, `s.split($/\s+/)`; `&` of one inside an expression is a borrow of the held one. A pointer into a held owner, and a change to one by a built-in method, are errors that say to bind it first | — | `var words = $"Hello, Kelvin!".split($/\s+/)` | 2026-10-19 |
| 188 | `b + c` on a Bytes is a new Bytes of the two, `b` a Bytes or text and `c` a Bytes, text or a byte 0 to 255, one a Bytes: a Bytes in a variable copied and kept, one an expression gives taken; a String and a Bytes are not joined | — | `a + b + "cd" + 0x7F` | 2026-10-19 |
| 189 | Kelvin is colored as Swift on GitHub, the language it reads most like: `.gitattributes` gives `.k` and `.kh` files `linguist-language=Swift`, and the examples of the documents, the README and Style.md are fenced ```` ```swift ````, which tests/docs.sh reads, as ```` ```kelvin ```` before | — | ```` ```swift ```` | 2026-10-19 |
| 190 | A TextMate grammar of Kelvin, `source.kelvin`, in editors/vscode, a VS Code extension that colors `.k` and `.kh` files and ```` ```kelvin ```` blocks of Markdown: keywords, declarations, the built-in and the modules' types, text with its escapes, templates with code in `${...}`, `$/.../` with its classes and groups, numbers, Kelvin's operators; installed by a link into `~/.vscode/extensions`; tests/grammar.js, run by `make test` where node is, checks it | — | editors/vscode | 2026-10-19 |
| 191 | `make vscode` installs the VS Code extension of editors/vscode: tools/vsix.sh packages it as build/kelvin-lang-<version>.vsix with zip alone, without npm, and VS Code's `code --install-extension` installs it, again over an installed one; `make vsix` only packages it; a link into `~/.vscode/extensions`, the way of #190, is not one VS Code loads | — | `make vscode` | 2026-10-19 |
| 192 | Kelvin builds on FreeBSD: kelvinc, the runtime, the C kelvinc writes and tests/asan.sh define _XOPEN_SOURCE and _DEFAULT_SOURCE on neither macOS nor the BSDs, which show POSIX, X/Open and their own extensions where no macro asks and hide their own where _XOPEN_SOURCE asks, as `sysconf(_SC_NPROCESSORS_ONLN)` and `getloadavg`; f.abspath of a renamed or removed file asks fcntl's F_KINFO there, there being no /proc | — | `gmake` on FreeBSD | 2026-10-20 |
| 193 | `make` on the BSDs: the build moves to GNUmakefile, which GNU make reads before Makefile, and Makefile, which BSD make reads, hands each target to `gmake`; README.md names what the build needs, GNU make, Python 3 and a C11 compiler, and on FreeBSD `pkg install gmake python3` or the ports devel/gmake and lang/python3 | — | `make` on FreeBSD | 2026-10-20 |
| 194 | CI runs on FreeBSD too: the job freebsd, in a virtual machine of vmactions/freebsd-vm, installs gmake, python3, node and zip with pkg, builds with gmake and the strict flags, and runs `make test` through BSD make, as a user, not root; FreeBSD names no removed file, so f.abspath of one is `""` there, as io.md says, and io_abspath.k and io_stat.k take that | — | the CI job freebsd | 2026-10-20 |
| 195 | f.abspath keeps the last name it found, of the path or of the descriptor, and answers by it where neither answers, as of a removed file on FreeBSD, which names none; `""` where none ever answered, as of a pipe, and once the IO is closed; the tests of #194 take one answer again on every system | — | `f.abspath` | 2026-10-20 |
| 196 | An IO keeps the name it opened as from the open on, the first that f.abspath answers by where nothing else does: IO(path) its realpath, IO(fd, mode) its descriptor's, OS.mkstemp's its file's; f.rename keeps the new one; a file removed before abspath was asked answers by the name it had on FreeBSD too | — | `f.abspath` | 2026-10-20 |
| 197 | `#inline C { ... }`: C of the program's own at the top level, written into the generated C where it stands, its lines the .k's; it ends at the `}` that matches its `{`, braces counted outside C's strings, characters and comments; the preprocessor is C's inside it; Kelvin uses its names as a header's, and it calls a Kelvin function above it by its C name; a module has it in its library, not its .kh; VS Code colors it as C | — | `#inline C { int one(void) { return 1; } }` | 2026-10-20 |
| 198 | `#inline C { ... }` in a function too: C statements where they stand among a function's, seeing its parameters and locals by their C names, their own, `$0` as `_kv_arg0`; a C `return` returns, and the owners it leaves are freed as by Kelvin's, by C's `cleanup` attribute; not in a struct, a union or an enum, nor as a brace-less body | — | `#inline C { total += i; }` | 2026-10-20 |
| 199 | A module's .kh has the declarations of its top-level `#inline C`, in an `#inline C` of their own, so a program that imports it uses the block's names: its preprocessor lines, a function's prototype, its types, a global `extern` without its initializer; nothing `static` or `inline` | — | `double geo_area(geo_size s);` in geo.kh | 2026-10-20 |
| 200 | A type and a variable at once in a module's `#inline C`, `struct p { ... } v = x;`, go to its .kh as `extern struct p { ... } v;`, and the tagged type of a `static` one alone, `struct p { ... };`; a variable of a struct type, `struct p v = {...};`, is `extern` too | — | `extern struct geo_rect { double w, h; } geo_unit;` in geo.kh | 2026-10-20 |
| 201 | examples/ski.k: SKI combinator logic, reduced leftmost-outermost to a normal form or a limit of steps, and Iota (`*` and `i`) and Jot (bits) compiled to it; `-iota` and `-jot` read a term of either from the command line, and a term of SKI otherwise | — | `kelvinc --run examples/ski.k -- 'S(K(SI))Kab'` | 2026-10-20 |
| 202 | examples/lambda.k: the untyped lambda calculus written with `λ`, never `\`: `λx y.M` for `λx.λy.M`, a number its Church numeral, a name in capitals one of Wikipedia's definitions (TRUE, AND, SUCC, PLUS, MULT, POW, PRED, SUB, ISZERO, Y, FACT, ...); normal-order reduction over de Bruijn indices, the names given back with `′` where one would capture; a term from the command line | — | `kelvinc --run examples/lambda.k -- 'PLUS 2 3'` | 2026-10-20 |
| 203 | `c ? a : b` of owners: `return c ? a : b` moves whichever arm it gives, a local or a parameter taken; two places, `c ? s : t`, are a place, read where they are and never copied by `=` or moved into a call; a place beside a value an expression gives is an error but where it is returned; `xs += c ? x : y` appends an element | — | `return paren ? $"(" + s + ")" : s` | 2026-10-20 |
| 204 | selfhost/, a proof of concept, not in CI: kc, a compiler of a subset of Kelvin written in that subset alone (the prelude and `<IO>`; libc is allowed, as to C, but C of our own is not), which writes C as kelvinc does for the same runtime and runs cc; selfhost/bootstrap.sh builds stage1 by kelvinc, stage2 by stage1, stage3 by stage2, and checks that stage2 and stage3 write the same C of kc, and that sample.k prints the same built by kc and by kelvinc; selfhost/README.md lists the difficulties of a Kelvin kelvinc | — | `selfhost/bootstrap.sh` | 2026-10-20 |
| 205 | `a[i].f = g()` makes g's value first, then finds the element: C evaluates the two in no order it promises, and gcc found the place first, so where g grew `a` the value went where its elements had been; `+=` and the rest too, a `Bytes`'s bytes, and the arguments of a method of an element, `xs[i].name += f()`; a call counts where it may reach the program's code, not the prelude's | — | `cells[0].v = grow()` | 2026-10-20 |
| 206 | `xs += &x`, `xs.append(&x)` and `xs.insert(i, &x)` of one element append a copy of `x`, by the copy of its type, a String's, a struct's that owns, an Array's, or the value of a plain one; it was C that did not compile, the pointer passed for the value, for every type of element, though the message for `xs += x` of an owner says to write `&x`; `&ys` of an Array of the same type is its elements, as before | — | `cells += &c` | 2026-10-20 |
| 207 | kc reads `#import <x.h> as C`: the header is included, and with one imported a name kc does not know is C's, unchecked, as kelvinc has it, with `nullptr`, `:=` of a `cstr` and a typedef as a type; kc uses libc itself: `getenv` for `KELVIN_HOME` (its modules/), `CC` and `TMPDIR`, and a temporary C file named by `getpid`, removed once cc is done | — | `#import <stdlib.h> as C` in selfhost/kc.k | 2026-10-20 |
| 208 | documents/c-contract.md writes down the C a program becomes, which another compiler of Kelvin must write to meet libkelvin and kelvinc's modules: the head of the file and its order, the build and its flags, GNU C's extensions it needs, the types of Kelvin in C, KV_ARRAY, KV_DICT and KV_SET, enums with values, Optional and Result, the four functions of an owner, cleanup and take, the names and their mangling, main and the runtime; provisional, as kelvinc's output is | — | documents/c-contract.md | 2026-10-20 |
| 209 | `d[$"a"] = 1`, a Dictionary's entry by a key that an expression gives, sets the entry: the key is held in a temporary around the place (#187), and the assignment now goes inside it, where its C could not assign; `+=` and the rest too, and any place held so | — | `d[key()] = 2` | 2026-10-20 |
| 210 | kc reads C's `enum` of names and `switch` as kelvinc has it: `case a, b:`, `default:`, a case its own block that ends with a `break` but after a jump, every enumerator named or `default:`, `default:` on anything but an enum; kc's own kinds of tokens, nodes and types are enums, and gen.k switches on them | — | `switch types[y].kind { case Y_I64: put("int64_t") ... }` in selfhost/gen.k | 2026-10-20 |
| 211 | kc reads `Dictionary<K, V>` of `String` or integer keys: `${:}`, `d[k]`, `d[k] = v` its set, `d.has(k)`, `d.get(k, default)`, `d.count`, its C KV_DICT as kelvinc writes it; kc's own functions, globals, structs, enums and enumerators are found by name in Dictionaries, indexed once before the C is written | — | `var fn_names:Dictionary<String, int64>` in selfhost/gen.k | 2026-10-20 |
| 212 | kc reads `String(n)` of a number or a `bool`, KV_STRING_OF as kelvinc writes it, and writes `true` and `false` as `(bool)`, so that String(true) is `true`; an owner an expression gives, passed to a function, is an error, since kc holds no temporary where kelvinc does (#187); kc writes its own numbers by String(n), its put_int and append_int gone | — | `out += String(n)` in selfhost/gen.k | 2026-10-20 |
| 213 | kc reads methods: `extend T { let m(...) ... static let f(...) ... }` and `let T.m(...)`, with `self`, `.x` and `Self` inside; `x.m(...)` is `T__m(x, ...)` and `T.f(...)` is `T__f(...)`, kelvinc's names, called straight; `return {a, b}` is of the function's type; kc's own `ty.owns()`, `node.jumps()` and `node.leaf(kind, t)` are methods | — | `types[y].owns()` in selfhost/gen.k | 2026-10-20 |
| 214 | kc infers a variable's type where it says none, as kelvinc does: `int64` of a number, `uint8` of a character, `bool` of `true`, `false` or a comparison, `String` of `$"..."`, the cast's of `as`, and what kc sees of a name, a call, a member or an element; `cstr` of text by `:=`; arithmetic, an empty `$[]` or `${:}`, `{...}` and C's alone are errors; a parameter or a member still says its type; `println` takes up to 16 values, as in kelvinc; kc's own variables of a literal say no type | — | `var cut = 0` in selfhost/kc.k | 2026-10-20 |
| 215 | kc reads enums with values, `enum item { none; num: int64; text: String }`, as kelvinc writes them: a struct of a tag and a union, `_kv_T_make_c`, `_at_c` checked, `_set_c` freeing what it held, `_free`, `_take` and `_copy` where a case owns; `T.c(v)`, a local owner moving in, `T.none`, `v.c`, `v.c = x`, `v.is(c)`, and a switch that binds a case's value; kc frees its global owners at exit by `_kv_free_globals`; kc's `load` gives `loaded.read(file)` or `loaded.unread(why)` | — | `enum loaded { read: int64; unread: String }` in selfhost/kc.k | 2026-10-20 |
| 216 | tests/asan.sh counts what realpath gives: count.c's kv_cnt_realpath counts the block of realpath(path, NULL), which the runtime frees, and the programs are built with realpath renamed to it, as malloc, realloc and free are; a count below zero, a free of a block never counted, fails, since it would hide as many leaks | — | `-Drealpath=kv_cnt_realpath` in tests/asan.sh | 2026-10-20 |
| 217 | kc reads `T?`, `Optional<T>` and `Result<T, E>`, making each the enum with values kelvinc makes, `struct _kv_opt_T` of none and some, `struct _kv_res_T_E` of ok and err; `none`, `ok(v)` and `err(e)` by the type that takes them, a T where a T? goes as some(T), `some(v)` a pattern alone; `x ?? d`; `if let c(v) = x { } else { }`; kc's `load` gives a Result and `case_named` an Optional | — | `let load(path:String^):Result<int64, String>` in selfhost/kc.k | 2026-10-20 |
| 218 | `d[k]` read whole is an Optional, `some` of a copy of the value or `none` where the key is missing; going into it is the place it was, checked: `d[k] = v`, `+=`, `d[k].m`, `d[k][i]`, `&d[k]`, `d[k]!`; postfix `x!` unwraps any Optional or ends the program, as `x.some`; `x?.m`, `x?.f(...)` and `x?[i]` chain as Swift's, `none` of `none`, an Optional the chain gives not wrapped again; an Optional where a value goes is an error that names `!` and `??`; `x ?? d` of an Optional of an Optional wraps `d` | — | `ages["bob"] ?? 0`, `ages["ann"]!`, `words["a"]?.count` | 2026-10-20 |
| 219 | kc reads `d[k]` whole as kelvinc does since #218: a `V?`, `some` of a copy of the entry's value or `none`; going into it is the place, checked; an Optional where a value goes is kc's error, naming `!` and `??` | — | `let seen = counts["c"]`, `if let some(t) = tags[3]` | 2026-10-21 |
| 220 | Kelvin has no trigraphs: `"what??!"` is the text as written; kelvinc writes a `?` after a `?` as C's `\?` in string literals, `#inline C`'s strings, characters and comments, a `.typename` and a `#line`'s file name; a `??` in `#inline C`'s code, or in the name of a header imported as C, is an error; kc writes its strings so too | — | `println("what??!")` | 2026-10-21 |
| 221 | kc chains as kelvinc does since #218: `x?.m`, `x?.f(...)`, `x?[i]`, the `?` right after `x`, the rest of the chain of a name bound to what `x` holds; `some` of what the rest gives, `none` of `none`, an Optional the rest gives not wrapped again; an owner the rest reads copied out; an `x` an expression gives read once and freed; `$[T]?` | — | `named(1)?.count ?? 0`, `spot?.sum()`, `maybe_hay?[2]`, `tags[3]?.count` | 2026-10-21 |
| 222 | An argument where a function or a method takes an Optional or a Result is what a return's value would be: `none`, `some(T)` of a `T`, `ok(v)`, `err(e)`, an owner moved in; among overloads `none` fits an Optional alone, `ok(v)` and `err(e)` a Result, and a `T` a `T?` only where no overload takes the arguments as they are; a `none` two Optionals take is a tie that names `Optional<T>()` | — | `take(none)`, `take(5)`, `b.plus(none)`, `g(5)` of `g(i64)` | 2026-10-21 |
| 223 | C's function of a name is called iff no Kelvin function of the name is declared before the call: beside one, C's is declared (`let sqrt(x:f64):f64`), keeps its C name and is an overload; arguments no overload fits are an error, and so is a function value of no overload's type; C's `_Generic` never falls back to C's function; a text literal fits a `String` parameter among overloads; an owner where an overload takes a borrow of it says to pass `&x` | — | `h("x")` of `h(v:String)` beside `h(v:i64)`; `let sqrt(x:f64):f64` beside `let sqrt(v:vec)` | 2026-10-21 |
| 224 | `some(v)` is a word, as `ok(v)` and `err(e)` are, where no function or variable of the name is in sight: a pattern alone; written as a value it is an error that says to give `v` itself, or `Optional<T>(v)`; where a Result goes, an error that names `ok` and `err`; `ok(v)` and `err(e)` where no Result is expected are errors that name `Result<T, U>.ok(v)`; none of the three is C's call of a function of the name | — | `return some(n / 2)` is an error: `return n / 2` | 2026-10-21 |
| 225 | kc frees a struct that owns, one with a member that owns, as kelvinc does: `_kv_T_free`, `_kv_T_take` and `_kv_T_copy`, so it is freed at the end of its block, moved out by `return`, held in an Array, a global freed at exit, and its old value freed by `=`; `{a, b}` of a struct reads each member by its field's type, `none` too, and a local owner there is an error that says `.copy()`; each type's C comes after the types it holds by value | — | `struct pet { name: String; tricks: $[String] }` | 2026-10-21 |
| 226 | kc frees an owner taken by value, as kelvinc's O5: the parameter is `_kv_x_in`, bound to a local `x` freed where the function ends or moved out by `return x`; a whole variable passed moves in by `_take`, one an expression gives goes in as it is, and a member or an element is an error that says to pass a borrow or a copy; methods take their arguments by their parameters' types too; `.copy()` copies any owner but an `IO` | — | `let shout(s:String):String`, `shout(hi)`, `sum_of(fibs.copy())` | 2026-10-21 |
| 227 | kc holds temporaries as kelvinc's #187: an owner an expression gives, where it is only read, is held in `({ T _kv_tmpN = ...; use; })` and freed once the expression is done: an argument not taken by value, `&f()`, a member, an element or a method of it, either side of `==`, the source of `for x in`, a statement that drops it; a member or element that owns is copied out of it, a pointer into it an error; a member or element is a place only where its base is | — | `println(String(42), " ", shout($"x").count, " ", adopt("ace").name)` | 2026-10-21 |
| 228 | CI's `selfhost` jobs, gcc and clang on Ubuntu and clang on macOS: `selfhost/bootstrap.sh`, whose stages reach a fixpoint and whose build of `sample.k` prints what kelvinc's does, and `selfhost/sanitize.sh`, kc built from stage2's C with ASan and UBSan, which must write the same C of `kc.k` and of `sample.k` | — | `selfhost / ubuntu-latest / gcc` | 2026-10-21 |
| 229 | kc prints an enum with values, an Optional, a Result and a struct as kelvinc does: `some(3)`, `none`, `some("kelvin")`, `ok(5)`, `num(5)`, `{x: 1, y: 2}`, by a `_kv_show_T` of kelvinc's form; what it holds is a number, a bool, text or another of them; kc reads `T??`, a number literal and `{a, b}` where an Optional goes, and `T.c(v)` of an enum with values in any program | — | `println(named(1), " ", p)` | 2026-10-21 |
| 230 | kc prints an Array as kelvinc does, `[1, 2]`, `[]` where empty, `["a"]`, `[{x: 1, y: 2}]`, `[[1, 2]]`, `some([1, 2])`, by a `_kv_show__kv_array_T` of kelvinc's form; selfhost/ is experimental, no longer a proof of concept, since CI checks it | — | `println(fibs, " ", points)` | 2026-10-21 |
| 231 | selfhost/README.md's difficulties brought up to date: kelvinc's 17,700 lines and kc's 3,900, what the subset has taken in since #204 (#207, #210, #211, #213 to #215, #217, #219, #221, #225 to #227, #229, #230), what it leaves out now (overloading, `?:` and O12, `try`, attributes, subscripts and operators, anonymous functions, templates, `Set`, `union`, `typealias`, floats and other integers, bitwise operators, `++`, `#inline C`, `#line`), 834 tests, 12 ms a compile | — | `selfhost/README.md` | 2026-10-21 |
| 232 | kc reads `c ? a : b` as kelvinc does: the loosest, grouping to the right, a `?` right after a value before `.` or `[` a chain's; of `a`'s type, or `b`'s where `a` is a word; each arm by the type that takes it, so `c ? n : none` of a `T?`; of owners O12: two places a place, read where they are, not copied by `=`; two values a value; one of each an error but where returned, which moves either out; kc's own source uses it | — | `return c ? s : shout($"other")`, `half(n) = n % 2 == 0 ? n / 2 : none` | 2026-10-21 |
| 233 | kc checks `=` and `:=` as kelvinc does: a reference, a `cstr` or a `T^`, takes `:=` and a value `=`, in a local's or a global's declaration and in an assignment to a name or a member, with kelvinc's messages, which name the type as Kelvin spells it; an Array and a Dictionary are not checked, as kelvinc does not; kc reads the assignment `p := q`, which it did not | — | `parity := odd ? "odd" : "even"` | 2026-10-21 |
| 234 | kc overloads functions as kelvinc does: a call gets the overload its arguments fit best by kelvinc's fit (the very type 2, a number or a `bool` that converts 1, a text literal to a `String`, `none` to an Optional, `ok(v)`/`err(e)` to a Result, a `T` to a `T?` in a second look), a tie or no fit an error (#223); a prototype and its definition one overload, one declared and never defined C's; each defined overload named as kelvinc's mangled_type names it, `twice__i64`, `show__vecp`, `f__opt_i64`, `f__Array_i64`, `f__res_i64_String`, `f__void`; a text literal given where a `String` goes is a `String` of it; a call of a name a variable hides is an error | — | `twice(21)`, `twice($"ab")`, `kind(none)` | 2026-10-21 |
| 235 | `d0 == d1` and `d0 != d1` of Dictionaries: the same entries in any order, each value by its own `==`; two of other key or value types, and values with no `==` (a struct, an Array), are errors; a Dictionary whose values compare has `==` itself, so an Optional, an enum or a Dictionary holding one compares too | — | `${"ann": 31} == ages()` | 2026-10-21 |

Notes:

- (2, 3) `*` means only multiplication. `p^^` is `**p` (and `p++^` was
  `*p++` until #26 removed `++`). Postfix operators apply left to right,
  so `p^[i]` is `(*p)[i]`.
- (4) Unary `~` is still bitwise NOT, in the same way that `-` is both unary
  and binary. Since `^` never means XOR, `p^ = x` is always an assignment
  through `p`, which is why `^=` is not a token.
- (5) Types are always written `name:type`, even for functions. A
  function's type follows its parameter list. A top-level `name(` starts a
  function, and a prototype ends with `;` or the end of its line (#35)
  instead of a body. Since #45 a function is declared with `let`:
  `let add(a:i64, b:i64):i64`.
- (6) These map to `<stdint.h>` types (`i32` is `int32_t`), plus
  `__int128` and `unsigned __int128` for `i128`/`u128`. The generated C
  includes `<stdint.h>` itself, so Kelvin source still needs no
  preprocessor. `i128`/`u128` only compile where the C compiler supports
  `__int128` (gcc and clang on 64-bit targets).
- (7) Using a C integer name is an error that suggests the replacement, e.g.
  `'long' is not a Kelvin type; use i64 or u64 (or i128/u128)`. The words
  stay reserved, because they are still C keywords in the generated code.
- (8) Only literals (optionally negated) are inferred, and only in `var`
  declarations: `x = y + 1;` still needs a type. #11 extends this to
  floating literals.
- (9, 10) `float`, `double` and `_Bool` are errors that suggest `f32`,
  `f64` and `bool`. The generated C includes `<stdbool.h>`.
- (11) This extends #8. A literal with a `.` or an exponent is `f64`.
  `true`/`false` were not inferred at first (`b = true;` needed `: bool`,
  Q8 answered no); #24 changed that.
- (12) `#import <x.h> as C` or `#import "x.h" as C` becomes `#include`.
  Everything the header declares is usable from Kelvin. It is the only
  directive, and the rest of the preprocessor is still TODO.
- (13) C's suffixes `u`, `l`, `ll`, `f` and their combinations are errors
  that suggest the typed declaration, e.g. `'10UL': literals have no
  suffixes in Kelvin; put the type on the declaration, e.g. 'x: u64 = 10'`.
  Hex digits `a`–`f` are of course not suffixes: `0xff` is fine. An
  unsuffixed literal still has C's type (`1` is an `int`), so C's
  `1UL << 40` is written `1:u64 << 40` (#16).
- (14) Both forms have exactly C's cast semantics: `i32(3.9)` is 3 and
  `u8(300)` is 44, except that a converter of text reads the number in it
  (#36). `T(v)` takes one value (and for text, a base: #36),
  and a statement may start with one. `(T)v` is an error that suggests the
  replacements.

  Kelvin cannot see C typedefs or macros, which leaves C room to read
  Kelvin text differently from how Kelvin parsed it. These guards keep
  that from happening silently:
  - **Casts to typedef names.** `(size_t)n` is caught by the token after
    `)`: a value, `!`, `sizeof`, `true`/`false`, a converter, or
    `++`/`--` before a name. `(T *)p` and `(T const *)p` are caught by
    their shape.
  - **Parenthesized names before an operand.** In `(size_t)-1`,
    `(size_t)(n)` or `(int32_t)*p`, Kelvin reads a subtraction, call or
    multiplication. Where a parenthesized name, call or index is followed
    by an operand (before a binary `-`, `+`, `*` or `&`, or as a callee),
    it is emitted with double parentheses: `((size_t)) - 1`. C never reads
    that as a cast, so it rejects the line instead. Elsewhere parentheses
    are printed as written, so `__attribute__((fallthrough))` and macro
    arguments are untouched. Under `sizeof`, a parenthesized operand other
    than a lone name is also doubled.
  - **C declarations at the start of a statement or `for` initializer.**
    These are rejected with the Kelvin spelling as a hint. A shape counts
    only when its declarator ends with `;`, `,` or `=`, or with a line
    end or `}` since #35, so `n * f(x) == 4 || g();` stays an expression.
    So do `a * b` and `a ~ b` where kelvinc sees that `a` is a variable
    or function (but not before `=`), where they are the one expression a
    body returns, or where `b` is declared in the same block already,
    since C does not read those as declarations. Examples:
    - `i32 * r = &x;` suggests `r:i32^`, and `const u8 *s` suggests
      `s:const u8^`.
    - `size_t a[3];` suggests `a:[size_t](3)`, `static size_t m;`
      suggests `static m:size_t`, and `size_t * (p) = q;` and
      `size_t * p^ = &q;` are caught too.
    - `size_t f(void);` points to function syntax, and a C function-pointer
      declarator such as `size_t (*f)(size_t);` suggests the function type
      `var f:(...):size_t` (#31).
    - `F ~ cb = 0;` is rejected, because Apple's clang reads the emitted
      `F ^ cb` as a block pointer.
  - **C compiler keywords** that act as prefix operators or type
    specifiers in C (`__extension__`, `__real__`, `typeof`, `_BitInt`,
    `__signed__`, ...) are rejected (P20). `_Pragma("...")` is allowed
    only as a statement of its own.
  - **Emitted form.** `T(v)` becomes `((T)(v))`, which groups `v` even when
    it is an unparenthesized macro such as `1.5 + 2.5`. `v as T` becomes
    `(T)v`, which is exactly C's cast.

  Known limitations, which follow from Kelvin not reading C headers. The
  user decided to keep the current guards and accept these, rather than
  read headers (Dialogue §20):
  - A statement `name(x);` or `name(x) = v;` is a call or a function-like
    macro (e.g. `ARR(i) = 5`), unless `name` is a typedef, in which case C
    reads a declaration of `x`. Converting to a typedef type is written
    `x as size_t`, never `size_t(x)`. Wrapping such statements in
    parentheses was tried and reverted, because it breaks header macros
    that expand to statements (`do { } while (0)`, `static_assert`,
    `timeradd`, ...).
  - A header macro that expands to nothing or to an operator can change
    how C reads the tokens around it. For example, macOS's
    `__BEGIN_DECLS * p` is C's `*p`. Kelvin treats every macro as an
    ordinary name.
  - `__asm__ __volatile__ (...)`, two names in a row, cannot be written
    in Kelvin. `__asm__(...)` can.

- (15) The user's own example: "`i = 42` is inferred as `i:i64 = 42`.
  `u = 0xdead:u16` is identical to ... `u = 0xdead as u16`." (The middle
  form in the original message read `u:u64 = 0xdead`, which was taken as a
  typo for `u16`.) Rules:
  - `name:T [= v]` declares (or `name:T [:= v]` for a reference, #19),
    at the top level, in blocks and in `for` initializers. Several
    declarators are separated by commas: `a:i32 = 1, b = 2;`.
  - `name = v` (or `name := v` for a reference) declares `name` when no
    enclosing scope (block, function, parameters, globals, functions, enum
    constants) has declared it.
    Otherwise it assigns. At the top level it always declares. The type is
    inferred from `v` (#8, #11): a literal, or a value written `v:T`,
    `v as T` or `T(v)`. Anything else needs `name:T = v`, or
    `name:T := v` for a reference.
  - In a declaration list inside a function, a later `name = v` or
    `name := v` whose name is already declared assigns it instead of
    redeclaring it. So `for (i = 0, n = 0; ...)` declares `i` and resets
    an existing `n`, and `k = 1, n = 40;` declares `k` and assigns `n`. At
    the top level every name in the list is declared.
  - Declaration wins over a label: `again: n = 0;` declares `again` of
    type `n`. Write `again: ; n = 0;` to label it.
  - A declaration cannot be the body of `for` or follow a label, as in
    C11 (`if`, `while` and `do` take blocks since #23).
  - `:=` was deliberately left unused here. It is now the reference
    assignment (#19).
  - Hazard: kelvinc does not see names declared by C headers, so
    assigning to a header global such as `optind` declares a new local.
    Declare such globals first with `extern optind:i32;` (Q11).
  - `var` is no longer reserved. `var x: ...` gets a hint.
  - #27 superseded these rules: declarations start with `let` or `var`,
    and a plain `x = v` always assigns, so the hazard with header globals
    and the declaration-or-label question are gone.
- (16) `expr:T` has the same precedence and meaning as `expr as T` (P17).
  A bare name after `:` is not an annotation in the middle operand of
  `?:` or in a `case` label, where `:` is the separator. A converter call
  such as `c ? x : u8(y)` is not an annotation either.

- (17) The prelude is available in every Kelvin program without an
  import. kelvinc includes `kelvin_prelude.h` in the generated C and links
  `libkelvin.a`. `print(a, b, ...)` prints its values with no
  separators, and `println(...)` adds a newline. Both take 0 to 16
  values. `print` and `println` cannot be redefined. This answers Q7:
  `println(n)` prints an `i64` on every platform. The same library and
  header work from C (`#include <kelvin_prelude.h>`, link `-lkelvin`).

- (18) Agreed details: methods are defined Swift-style as
  `point.area():f64 { ... self ... }` with an implicit `self`.
  `toString()` and `fmt()` returned a `String`, a fixed inline buffer.
  Every struct got a derived `toString()` that could be overridden, and
  `f64.toString()` was `fmt("%.17g")`, which is lossless. `print` keeps
  its own formatting (P21). The user's example `pi.fmt("5a")` was read as
  `pi.fmt("%a")` (Shift+5), which gives `"0x1.921fb54442d18p+1"`. #22
  shelved `toString()`, `fmt()` and `String`; their code is in the git
  history (commit 8eb42bc and before).

- (22) Agreed details: `toString()`, `String` and `fmt()` are all shelved
  until Kelvin has a true string type (a la C++ and others). `x.cstr`
  gives the text `toString()` gave, as `cstr` in a buffer on the stack
  like `.dec`. A struct's `.cstr` is derived (`{x: 3, y: 4}`), with a
  buffer kelvinc sizes from the member types, and cannot be overridden
  for now. `cstr` is a built-in type name for `u8^` (`uint8_t *` in C),
  not a `typedef` declaration: Kelvin still has none.

- (23) Agreed details: `bool` was already built in (#10) and `b.cstr` is
  `true` or `false`; `.cstr` stays a property. Strictness covers every
  condition: `if`, `while`, `do`, `for` and `?:`, and the operands of
  `&&`, `||` and `!`. `if`, `while` and `do-while` drop their parentheses
  (`do { ... } while cond;`), while `for (...)` and `switch (...)` keep
  them for now. The C compiler enforces `bool` where kelvinc cannot see a
  type, and comparisons and logical operators give a real `bool`, so
  `println(a == b)` prints `true`. Without parentheses a body must be a
  block, as in Go, Swift and Rust.

- (24) `t = true;` declares a `bool`: `true` is a `bool` literal, so its
  type is as obvious as `42`'s or `1.5`'s. This reverses the note on #11.
  Other `bool` values, such as `ok = a < b;`, still needed `: bool`
  until #25.

- (25) Agreed details: every `bool` expression infers `bool`, with one
  exception the user accepted: a `bool` kelvinc cannot see, such as the
  result of a C function from a header, still needs `: bool`. The user
  asked whether `ok = a < b` could be read as `(ok = a) < b`: it cannot,
  since assignment has the lowest precedence, as in C.

- (26) Agreed details: assignment (`=`, `:=`, `+=`, ...) is a statement
  with no value, and `++` and `--` are gone, as in Swift. Pointers get
  `.next` and `.prev` instead. Index expressions must not change
  anything, which follows: nothing inside `[...]` can assign. "The good
  old days of `*p++ = *q++;` are gone." A `for` init or step takes a
  comma list of assignments.

- (27) Agreed details: the user wanted `var` back to mark mutability, and
  chose `let` over `val` for the immutable binding, as in Swift. `let i =
  42; i += 1;` is an error. Every local and global declaration starts with
  `let` or `var` (`let x = 42;`, `var n:i32 = 0;`,
  `static var calls:i32;`), so a plain `x = 0;` always assigns, which
  also ends #15's guessing between declaring and assigning. Parameters
  are lets unless written `var`, as in `f(var p:i32^) { p := p.next; }`,
  and a method's `self` is a mutable copy (`self.x += 1` is fine). A
  `let` is C's `const` (agreed in the discussion): a let pointer is
  fixed, but what it points to may change. Struct members keep
  `name:type;`.

- (28) Agreed details: C's counting `for` is discouraged in favour of
  ranges, `for i in 0..<count { }` (half-open) and `for i in 1...n { }`
  (closed), where `i` is immutable in the body. `i`'s type comes from the
  bounds (or is written, `for i:u8 in ...`), and ranges exist only in
  `for` for now. C's `for (...)` stays, written `for (var i = 0; ...)`.

- (29) Agreed details: `struct st` and `union un` are "auto-typedef'd", so
  `st` and `un` are types without the keyword; the user chose to include
  enums, as C++ does, and to keep `struct point` working as well.

- (30) Agreed details: loops such as `while s^ != 0 { ...; s := s.next; }`
  are frequent, so `for c in s { }` walks them, for any sequence ended by
  a terminator value (usually `'\0'` or `nullptr`), linked lists
  included. For a list, the loop variable is each node's pointer, found
  through the `next` field. An array of known length is walked up to its
  length, breaking early at the terminator. A `nullptr` string is empty.

- (31) Agreed details: anonymous functions (#32) need their parameters'
  types, and kelvinc cannot see those of a C header's functions, so Kelvin
  got function types first. The user chose `(T, U):R`, the shape of
  Swift's `(T, U) -> R`, over `fn(T, U):R` and `((T, U):R)^`.

- (32) Agreed details: the user asked for anonymous functions without
  closures ("True closures are too much for normal C (ignore GNU
  extensions)"), with Swift's trailing form, `$` as the argument stack,
  `$[idx]`, and `$0` for `$[0]`. Where no type is in sight, the user chose
  Swift's `{ (a:T, b:U):R in ... }` over an unnamed function head and
  `{ ... } as (T, U):R`. A body of one expression is the result
  (`{ $0 < $1 }`). `$[k]` takes a decimal number only, since each
  parameter may have its own type, and `$` works only in anonymous
  functions.

- (33) Agreed details: "anonymous function are inlined by default". The
  user chose C11's `static inline`, a hint the C compiler follows when
  optimizing, over GNU's `always_inline` and over kelvinc specializing
  the callee itself. There is no way to opt out for now; one may come
  with a Kelvin spelling of `inline` for named functions.

- (34) Agreed details: "every variable has `.type` where
  `v.type == typeof(v)`. if possible, add `.typename` which returns a
  `cstr`". The user chose: `.type` goes where a type goes, and in an
  expression `x.type` stays a field (C structs often have one); it is
  the type kelvinc sees, else `__typeof__`; `.typename` is the Kelvin
  spelling, else `_Generic`'s name of a built-in type, else `"?"`. The
  user's earlier `(p0 - p1).diff`, a `ptrdiff_t`, was to wait for a
  change of its own (Q13), and was later set aside.

- (35) Agreed details: "like many modern languages, `;` can be omitted
  if the statement ends in line and `return` is not necessary for
  expressions." The user chose Swift's rule (a new line ends a statement
  once it is complete; an operator, `.member`, `[`, `?`, `:` or `as` on
  the next line goes on, a `(` or `{` there starts the next statement)
  over Go's; `return` may be left out where a body is one expression, as
  in Swift, rather than for the last expression; and `;` stays valid,
  while Style.md, the examples and the docs leave it out (the tests keep
  both forms). After review the user chose, over Swift's literal rule
  and over Rust's (`;` makes it a statement), that one expression is not
  returned where kelvinc sees it has no value (`println`, a function with
  no result, `_Pragma`), and that `main` keeps C's rule that its end
  returns 0, so `main():i32 { printf("hi\n") }` exits 0. They also chose
  Swift's `return` over Go's in a function with a result: there
  `return` at the end of a line takes the expression on the next line,
  while in one with no result it ends at its line and kelvinc reports a
  statement after it in the same block, which could never run.

- (40) Agreed details: "you can `#import <lib/complex.k>`". The user
  chose that an import brings in the file's source, compiled with the
  program as if written in place, rather than a separately compiled
  library with a generated header. `<...>` is looked for in Kelvin's
  home, where the runtime is (`$KELVIN_HOME`, kelvinc's directory, its
  parent), and `"..."` next to the importing file.

- (41) Agreed details: "ensure that kelvin is multi-dispatch.
  `sin(r:f64):f64` is distinct from `sin(z:complex):complex`." The user
  chose that only overloaded and imported functions get C names made
  from their parameter types (`sin__complex64`), while a program's one
  function of a name keeps its name. So that a Kelvin function can
  overload C's, one that shares its name with a C function the program
  calls is named so too (P52). Overloads are chosen statically by the
  types kelvinc sees, and by C's `_Generic` where only C sees an
  argument's type.

- (42) Agreed details: the user chose operators over named functions
  (`cadd(a, b)`) for complex arithmetic. An operator is a function
  written with the operator as its name, overloaded by its types like
  any other.

- (43) Agreed details: "add `lib/complex.k` That implements complex
  arithmetics including elementary functions. DO NO USE C99's Complex.
  `struct complex { real:f64; imag:f64 }`. `exp(z) =
  exp(z.real)*{cos(z.imag), sin(z.imag) }`, for instance. maybe `complex`
  should be named `complex64` with corresponding implementation of
  `complex32`. we are yet to go for generics (even I am tempted to)." The
  user chose "complex{32,64,128} where f{32,64,128} are available. the
  last one might not be available for some platforms. complex128 iff
  f128 is available on the platform", and then `complex32` and
  `complex64` now, `complex128` with `f128` later. The number is the
  size of each part, as in `f64`.

- (44) Agreed details: "let's make template literals heap-free. so far
  as I know that is the only feature of kelvin which implicitly use
  heap." An audit confirmed that templates were the only implicit heap
  use in kelvinc's C, the prelude and libkelvin; libc's own (the stdout
  buffer, and on macOS a small cache for formatting floats) remains, as
  for C's `printf`. Of three designs, the user took the bounded one, with
  each recommendation: a string value is cut at 256 bytes, as P35 cuts a
  string member (`KV_TEMPLATE_STR`, which `-DKV_TEMPLATE_STR=n` changes);
  each evaluation builds its text in a buffer of its own and then copies
  it, as before, so the order of evaluation and ``s := `${s}b` `` stay as
  they are; the check that the text does not outlive its block stays as
  it is, its gap for fields, elements and `p^` (shared with `.hex` and
  `.cstr` text) left for a later change; and for longer text there is
  only the macro for now, writing a template into a byte array to be
  proposed later.

- (45) Agreed details: "make `let` mandatory for toplevel functions.
  Kelvin allows anonymous functions meaning internal functions are
  available like `var idi64:(x:i64):i64 = { x }` possible. mandating
  `let` makes the language a little more consistent." Methods and
  operators are functions, so they take `let` too, and `static` or
  `extern` goes before it, as for a variable. The user chose to keep
  functions at the top level: inside a function, `let f(...)` is an error
  that shows the anonymous function a let holds there (#32); `var f(...)`
  is an error too, since a function never changes (P57).

- (46) Agreed details: "move `lib/` to `modules/` and move
  `libkelvin.{a,dylib,*.so}` therein. add `./modules/` default search
  directories of the language. Both "include" files and compiled
  libraries can reside." The user chose, with each recommendation: `<x.k>`
  is looked for in `./modules` of the directory kelvinc runs in, then in
  Kelvin's own `modules/`, so `<lib/complex.k>` is now `<complex.k>`;
  both are where C looks for headers and libraries too (`-I` and `-L`),
  while kelvinc links only libkelvin itself; and `kelvin_prelude.h` moves
  to `modules/` as well, which `make install` copies to
  `$PREFIX/lib/kelvin/modules` (P58).

- (47) Agreed details: "why can not you infer the type of `i`? RHS is
  obviously `complex64`." The rule of #11, #24 and #25, that only
  literals, bools and annotated values infer a type, dates from when
  kelvinc knew no types; since #41 it tracks the result type of every
  Kelvin function and method, and #25 already infers `bool` from one.
  The user chose to infer from every value whose type kelvinc sees,
  "with arithmetic excluded": `small + 1` has C's promoted type, which
  would surprise. A value only C sees still needs a written type, since
  `__auto_type` would leave kelvinc blind to it (P59).

- (48) Agreed details: "use `[]` for array initializations.
  `[0,1,2,...]` instead of `{0,1,2,...}`. struct/union inits remains
  the same." The user chose, with each recommendation, that `{...}` for
  an array kelvinc sees, and `[...]` for a struct, are errors with a
  hint; that an array literal infers its type from items of one type,
  as #47 infers from seen values; and for compound literals
  "`(i32[])[1,2,3]`. the number of the elements are inferred from rhs."
  (P60).

- (49) Agreed details: "change array type from `T[]` to `[T]` like
  swift. `[T]` has an attribute `.count` that is set during
  initialization. `var a = [0,1,2,3]` is a type `[i64]` and `a.count` is
  4. The size never changes. Variable-sized array like python, swift,
  etc is to do. to make an empty array, you go `[T](count)`. You get
  `count` number of zero-filled elements. an array also has `.size`
  attribute which is simply `a.count * sizeof(T)`. `var` arrays don't
  expand or shrink but its elements are mutable. `let` arrays locks its
  elements as well. kelvin promotes array logic rather than pointers.
  We use pointers only when it is necessary. yet `var p := a` still
  works. `p^` is now `a[0]`." The user chose, with each recommendation:
  `[T](N)` is also the type with a count, where a struct member or an
  uninitialized global needs one; `[T](n)` may take a count C computes
  at run time, as C's VLA, in a local `var`; and a parameter `a:[T]` is
  C's pointer, where `.count` is an error (P61). `T[N]` and `T[]` are
  errors whose hint spells the type the new way, which rewrote every
  array type in the repository.

- (50) Agreed details: "add `.isNull` to pointer types. `p.isNull` is
  more concise and easy to read than `p == nullptr`." It follows the
  rules of `.addr` (#37): every pointer and function value kelvinc
  sees, a field where it is unsure, an error on an array (P62).

- (51) Agreed details: "reintroduce `++` and `--` just for pointers,
  postfix only. `p := p.next` seems a little too wordy. if p is not
  `var` it is a compile-time error." They are statements, as every
  assignment is (#26), so `p++` has no value and `p++^` is an error;
  `.next` and `.prev` stay as the values (P63).

- (52) Agreed details: "Let us make it clear that `cstr` is more strict
  than `char *`: it is `[u8]`, not `u8^`; it is immutable. so
  `s = "I love to hate C"; s[0] = 'U'` is a compile error; `var p:u8^ :=
  cstr` is still allowed but not encouraged; promote `cstr` over
  `char *`." On `.count`: "strlen(s) for the first use, then sticks till
  the end of the scope. It is okay because It never expands. in C it
  will be stored in `_kv_` variables iff it is actually used." Then
  "errors for stepping, implicit cast": `s++`, `s.next` and `s + 1` are
  errors, and `var p:u8^ := s` gets its cast from kelvinc (P64).

- (53) Agreed details: the user wrote `let vector2d.cstr():cstr {
  `{${self.x}, ${self.y}}` }` and got "expected ':', found '.'", as
  `cstr` is a keyword. Claude explained that the derived text is
  written into the caller's buffer, which a method's own template could
  not be returned into, and proposed a `.cstr` method whose body is one
  template, which kelvinc compiles into that writer, sized from the
  template; the user: "go with the cstr override, one template body"
  (P65).

- (54) Agreed details: the user asked for growable `String`, `Array`
  and `Dictionary` that use the heap safely, keeping `--emit-c` and no
  generics or collector, and chose, among borrow checking, reference
  counting and a collector, ownership by scope with moves and borrows
  (Dialogue.md entry 84); `Bytes` over `Data` as the first owner; then
  "implicit moves, copy only by .copy(), abort out of range, doubling".
  The rules O1 to O10, once proposed here, are now in
  documents/ownership.md, and their details in P66. `b += x` is
  `b.append(x)`, since an owner may not be copied as `x = x + y`.

- (55) Agreed details: "now add `String`, a sequence of codepoints on
  `Bytes`", as the user had set it out: "`String` is a sequence of
  Unicode codepoints. it iterates by codepoints and malformed byte
  representation is forbidden. Generically speaking it is `Array<u8>`
  but should be treated specially." The details are P67; the
  codepoint is a `u32` for now, and whether it should be a type of its
  own is Q15.

- (56) Agreed details: "`for c in s {...}` gives a stream of integers
  representing codepoints which is a little inconvenient. It should be
  `uchr` type on a stack which is a Unicode codepoint internally yet
  stringified as a utf-8 `cstr` so it prints fine with `print()` and
  friends. `uchr` types has `.utf32` attribute which returns `u32`.
  `.codepoint` can be its alias. Also give array types `.uchr`
  attribute which converts its integer value to `uchr`, `U+0000` if
  failed (is `U+FEFF` better?)" Claude read "array types" as integer
  types, and chose U+FFFD, the replacement character, which Unicode
  defines for this, over U+0000 (a NUL, which ends C text) and U+FEFF (a
  byte order mark). This answers Q15 (P68).

- (57) Agreed details: "now add `Array`, a growable array of `T` on the
  heap". The spelling `Array<T>` is Claude's, provisional, as Kelvin
  has no generics: one built-in generic, instantiated by a C macro per
  element type (P69). Elements that own (a `Bytes`, a `String`, an
  `Array`) were included, as `Array<Array<i64>>` and `Array<String>` are
  the first things wanted; a struct that owns as an element waits.

- (58) Agreed details: "Why doesn't `var va = Array([0,1,2,3])` work? It
  should work as `var va = Array<i64>()` followed by four `append`s".
  `Array([...])` takes the elements as a fixed array's initializer and
  infers `T` from them by the rule a variable's type follows (#47, #48);
  `Array<T>([...])` gives `T`. "`Array([ [0], [0] ])` should be parsed
  as `Array([Array([0]), Array([0])])`": a `[...]` among the elements
  is an Array, never a fixed array, which cannot be an element.
  `Array(a)` and `Array(&other)` infer `T` from the argument as well;
  `Array()` and `Array(n)` cannot, and say so (P70).

- (59) Agreed details: "add an anonymous `struct`, like `var v:{x:f64,
  y:f64} = {0.0, 0.0}`". Claude made one spelling one type, since C's
  own anonymous structs are each a type of their own, which would make
  `v` unpassable to `let f(v:{x:f64, y:f64})`; the C struct is tagged
  `_kv_anonN` and declared before the first top-level declaration that
  writes the spelling (P71). Methods and operators on one, and a union
  with no tag, wait.

- (60, 61) Agreed details: "add an anonymous `union` too, like `var
  u:union{i:i32, f:f32}`. And 'smart union' like Swift's enum which
  knows its current effective type at run time. It will lose a byte
  (beyond 255 types are quite unlikely) but it will benefit handling
  data types like JSON." Asked which spelling, Dan chose `enum` with
  typed cases (Swift's, a C enum when no case has a type) over `tagged
  union` and a new keyword, and members checked at run time (`v.n` ends
  the program if another case is current, as `xs[i]` does out of range;
  `v.is(n)`; `switch (v) { case n: }`) over a tag number with constants
  and over Swift's patterns. The tag is a byte, the cases' index from
  0; `T.n(x)` and `T.none` make a value as Swift's `.n(x)` does, with
  the type's name as Kelvin has no leading dot. For JSON, an enum must
  hold an `Array` of itself and own, so #61 also derives `.copy()` for
  a struct that owns and lets one be an Array's element (P73).

- (62) Agreed details: "`String("...")` and `Array([...])` seems too
  long, may keep users away from using. As a human I feel the need for
  the shortcut. How about prefixing them with `$`? `$"I needed it"` is
  `String("I needed it")`, `$[[1,0],[0,1]]` is `Array([[1,0],[0,1]])`".
  Done as asked; `$[k]` of one number stays an anonymous function's
  parameter inside one, where `Array([k])` spells the Array (P74).

- (63) Agreed details: "Regarding `switch`-`case`, does the current
  kelvin need `;break;` like C? If not, make it unnecessary like Swift
  and many other modern languages. And make it exhaustive too. Duff's
  devices should be blown in the wind. You may add `default:` keyword."
  It did need `break`. Now a case ends at the next; `case a, b:` takes
  fallthrough's place for one body; an empty case before another is an
  error, as it would have meant a fallthrough; a case inside a
  statement of the switch is an error; every value is handled, by the
  cases of an enum with values or of a Kelvin enum, or by `default:`,
  which was C's keyword already. With that, the parentheses of P37 go:
  `switch n {`, as `if` has it (P75).

- (64) Agreed details: "`var va:$[[i64]]` should work as an alternate
  expression of `var va:Array<Array<i64>>`. `$` magic applies to type
  declarations as well." Done: `$[T]` where a type goes is `Array<T>`,
  nesting as the value does, so a fixed array is never meant inside;
  `$[[i64](3)]` says so. `$` before anything else in a type says what
  `$[T]` is, since a String has its name (P76).

- (65) Agreed details: "now add `Dictionary`, a hash map on the heap.
  Here it comes!" Claude chose Swift's spellings with the `$` of #62
  and #64, `$[K: V]` and `$[k: v]`, `$[:]` for an empty one; keys of
  integers or Strings only, a String key kept as a copy of the text and
  looked up by text, so that a literal, a template or a String all
  serve; `d[k]` checked as `xs[i]` is, `find` for a borrow or nullptr
  and `get` for a default, in place of an optional; entries in the
  order added, so that a walk and a print are predictable (P77).

- (66, 67) Agreed details: "now add `keys` and `values` to
  `Dictionary`, as `Array`s. Also edit `documents/arrays.md` and others
  so it covers dynamic, heap-allocated versions as well besides
  `documents/ownership.md`. Also add `` $`...` ``, a dynamic version of
  template string." `keys` and `values` are properties giving Arrays of
  copies, in the order added, which a variable then owns (P78); `` $`...` ``
  is a template appended into a String, each value's text as the
  bounded template shows it, a String's whole (P79). The type documents
  now each carry the heap version beside the C one: arrays.md has
  `Array<T>`, cstrings.md `Bytes` and `String`, and dictionaries.md is
  new; ownership.md keeps the rules.

- (68, 69) Agreed details: "now add slicing to `Array` and `String`.
  Also change Dictionary literal notation from `$["key":value]` to
  `${"key":value}`. Being a Swift user I like the former better but
  the rest of the world is more accustomed to braces than brackets :("
  A slice is a copy, as the rules allow no view yet; a String slices by
  codepoint, and a Bytes came along by bytes (P80). The literal is in
  braces, with `${:}` empty; the type keeps `$[K: V]`, as nothing asked
  for it to move, and `$[k: v]` says where to write it now (P81).

- (70) Agreed details: "now change the Dictionary type to `${K: V}`
  too. Also add at least a synopsis of properties/attributes or
  description if necessary, to example/T.md. You are squeezing too much
  in properties.md." Read as: each type's document (`documents/T.md`)
  gets a synopsis table of its properties and methods, and
  properties.md keeps the ones every value shares, with an index to the
  tables (P82).

- (71) Agreed details: "now add `Set`, a hash set on the heap". Spelled
  as a Dictionary with no values: `${T}` and `${a, b, c}`, Python's
  rule that braces without colons are a set, `${}` the empty one where
  the type is known; the elements are a Dictionary's keys. `union`,
  `intersection` and `difference` take a borrow and give new Sets, the
  first two named as Swift names them, `union` read as a method though
  it is C's keyword (P83).

- (72, 73) Agreed details: "now add `Optional`, a value that may be
  absent. Also add binary `|`, `&`, and `~` operators to `Set`". An
  Optional is built on the enum with values of #61: `T?` is one with
  the cases `none` and `some: T`, so switching, `.is`, `.case`, the
  checked `.some`, the text and the ownership come as they are; Swift's
  `T?` spelling and `??` were added, `none` as a word read where a `T?`
  is expected, and a `T` wrapped by itself there (P84). The Set
  operators are the methods by another name, `~` being Kelvin's xor
  (P85).

- (235) Agreed details: "add the following features to `Dictionary`:
  `==`. Both key types and value times must match. If not, fatal
  error. `d0.merge(d1){ v0, v1 in ...}` ... `.merging()` ... `d0 ?? d1`
  and `d0 !! d1` like swiftalk's Dictionary.md". Asked, the user chose:
  three changes, #235 `==`, #236 `merge` and `merging`, #237 `??`
  and `!!`; a value type with no `==` is an error at compile time;
  untyped `{ v0, v1 in ... }`, the new value winning without one; and
  `??=` and `!!=` too, `!!` binary. A Dictionary's `==` is its `_eq`,
  written after KV_DICT where its values compare, which is decided
  once parsing is done, since an enum of its values may hold it: JSON
  holds a Dictionary of JSON, and has no `==` because of its Array.

- (234) Agreed details: "teach kc overloading as #234". kc kept the
  first function of a name and called it whatever the arguments were.
  It counts each name's signatures now, chooses a call's overload by
  kelvinc's scores, `bool` a number among them as kelvinc's
  numeric_type has it, and names the defined overloads in C as kelvinc
  does. On the way: a text literal given to a `String` parameter was
  left as text; a local named as a function hid it in kelvinc's build
  but not in kc's, which the sample's `twice` met; and kc reads no
  `x == none`, which gen.k had to write as `.is(some)`. The overloads
  of methods, and kelvinc's names of an imported file's functions, are
  left.

- (233) Agreed details: "fix kc's cstr = check as #233". kc took
  `let s:cstr = ...` (P244), and so a value by `:=`; it read no
  assignment by `:=` at all. kelvinc's check_assign_op is best effort:
  a type it does not classify, an Array or a Dictionary, is not
  checked; kc leaves the same alone, so that what kelvinc takes kc
  takes.

- (232) Agreed details: "teach kc c ? a : b as #232". kc wrote no `?:`;
  it parses one now after the binary operators, so that `?` stays a
  chain's where it touches a value before `.` or `[`, as in kelvinc. Its
  owners follow O12 with kelvinc's messages. kc infers a type from
  `c ? 10 : 20`, which kelvinc does not; and kc takes `let s:cstr =
  ...` where kelvinc asks for `:=`, which the sample found.

- (231) Agreed details: "update the selfhost README's subset list as
  #231". The list of #204 named type inference, methods, Dictionary
  and ownership's moves and temporaries as left out; kc has them now,
  listed beside the change of each. What is left out was read off kc's
  lexer and parser, not from memory: no `?:`, no bitwise operator, no
  float. The counts were taken again: wc -l, tests/run.sh, and 20
  compiles of kc by stage3.

- (230) Agreed details: "teach kc to print Arrays as #230. Also mark
  `selfhost` from "proof of concept" to "experimental" now that it is
  on CI." An Array is shown as its elements between kv_out_sep and
  kv_out_end, as kelvinc's. "Experimental" is said where "proof of
  concept" was: the READMEs and kc.k's head; the history of #204 keeps
  its words.

- (229) Agreed details: "teach kc to print Optionals as #229". kc left
  an Optional to C's print, which took it for a pointer. It writes
  kelvinc's printers now, and a struct's, which an Optional of one
  needs. On the way: kc lexed `T??` as `??` and could not read it as a
  type; a number literal became `some` of an `int64?` alone, and `{a,
  b}` where a `T?` of a struct goes was the Optional's own initializer;
  and `T.c(v)` of an enum with values was a name kc did not know where
  the program wrote no `T` as a type. An Array inside is left.

- (228) Agreed details: "add the selfhost bootstrap to CI as #228".
  The checks run by hand since #204 are jobs now, and the sanitizer
  build of kc, run by hand too, is a script. `CC` picks every stage's
  compiler. The counting allocator's run of kc's programs stays by
  hand, since tests/asan.sh builds with kelvinc.

- (227) Agreed details: "teach kc to hold temporaries as #227". kc
  refused `println(String(n))` (#212), and left `f().count`,
  `f().m()`, `&f()` and a dropped `f()` to leak or to C's errors. kc
  writes kelvinc's C now, a temporary named `_kv_tmpN` that gen_expr
  writes in place of the expression held. On the way: `==` of two
  Strings an expression gave held only one; an `x` made by a chain was
  missing from kc's index of names, built once before the functions,
  so `f()?.m ?? 0` failed where the program wrote no `T?`; and kc does
  not print an Optional yet, which kelvinc shows as `some(...)`.

- (226) Agreed details: "teach kc to free owners passed by value as
  #226". kc passed an owner by value as a shallow copy, which the callee
  never freed, and the caller freed again where it was a variable; kc
  writes kelvinc's C now. An owner an expression gives may go to such a
  parameter, since the function frees it; elsewhere kc still asks to
  bind it (#212). A method's arguments were written without their
  parameters' types, so `none` and a moved owner went wrong there too.
  `.copy()` was a String's alone.

- (225) Agreed details: "teach kc to free structs that own as #225".
  A struct whose member owned was not an owner to kc, so nothing freed
  it. is_owner now looks into a struct's members, and kc writes the
  struct's functions as kelvinc's. A struct with a `$[String]` member
  needs the Array's C first, and an Array of the struct the struct's,
  so kc writes each type once after what it holds by value, which also
  takes the place of #221's order of enums. `{a, b}` read its members
  without their types, so `none` in it was a C error; gen_init gives
  each its field's type.

- (224) Agreed details: "fix the bare some(v) message as #224". kelvinc
  left `some(5)` to C, whose message was of an undeclared function
  `some`, wherever it stood; `ok(5)` and `err(5)` did the same where no
  Result was expected. `some(v)` is a word now, so a pattern still takes
  it, and a word that nothing expecting its type took is an error when
  the C is written. A program's own `some` is called as before.

- (223) Agreed details: "fix the String literal overload bug as #223.
  Let us make it so C function is used iff no kelvin function with a
  same name exists. Update functions.md accordingly." This ends P52:
  a Kelvin function of a C function's name no longer overloads C's,
  which took what no overload did, so a mistaken argument went to C,
  as `h("x")` did. A declared, undefined function was already C's, and
  is the way to call C's beside Kelvin's; `#import <math>` declares
  them. As in C, a call sees the functions declared before it, so a
  call before a Kelvin function of the name is still C's.

- (222) Agreed details: "fix the take(none) bug as #222". A call of one
  function wrapped nothing: `take(5)` went to C's function of the name,
  as a number where a struct goes, and `take(none)` to a `_Generic`
  between `take__opt_i64` and C's `take` of `none`, an unknown name;
  methods too. Arguments are wrapped as returns are now, before the
  checks. Among overloads `fit` reads `none`, `ok(v)` and `err(e)`, and
  a second look of `choose` lets a `T` fit a `T?`, so that an overload
  of the `T` itself still wins. Found: with overloads, a text literal
  fits no `String` parameter, and goes to C (P234).

- (221) Agreed details: "teach kc x?.m chaining as #221". kc's postfix
  loop is parse_steps now, and an adjacent `?` before `.` or `[` makes
  an N_CHAIN whose rest is parse_steps of a made name. The `T?` a chain
  gives may be made only while a function is written, after the enums
  were, so kc writes the functions into a String of their own and puts
  the enums made meanwhile before them. On the way: kc asked the type of
  a bare `none` in a `return` and an argument, which its sample hid by
  having an enum case `none`; `??` named its temporary by a serial a
  chain inside it moved; an enum holding an Array came before the Array;
  and kc does not free a struct whose fields own. kelvinc writes
  `take(none)` as an overload's `_Generic` of `none`, a C error (P233).

- (220) Agreed details: "fix the trigraph bug as #220. WE DO NOT
  SUPPORT TRIGRAPHS. It is terribly obsolete in the age of Unicode."
  C11 reads trigraphs in -std=c11 before anything else, and gcc has no
  switch to stop it (clang's -fno-trigraphs is clang's alone), so
  kelvinc writes C with none: `\?` is C's escape of `?`, and the text is
  the same. Templates, `"""` and `$/.../` escaped every `?` already;
  `"..."` and `#inline C` did not. A `??` in `#inline C`'s code could
  only be a trigraph, and a header name has no escapes, so both are
  errors. kc's message of #219 says `'??'` again.

- (219) Agreed details: "teach kc d[k] as an Optional as #219". kc
  makes the `V?` of a Dictionary's `V` as it reads `Dictionary<K, V>`,
  so the enum comes before the code that uses it; `d[k]` read whole is
  C's `_find`, a copy of an owner's value in `some`, and no place, so
  `if let` holds it and frees it. kc said nothing of an Optional where a
  value goes, and C did; it says so as kelvinc does. `x?.m` is left.
  Found on the way: kelvinc writes a Kelvin string as C's, so `??!`,
  `??'` and the other trigraphs of C11 change it (P231).

- (218) Agreed details: "`Dictionary` currently dies when `d[k]` is
  nonexistent. Let's change it to return `Optional`. postfix `!`
  unwraps the result or dies. postfix `?` unwraps the result or
  `none`." Asked, the user chose: `?` chains, as Swift's, `try x`
  keeping the early return; `d[k] += 1` and `d[k].append(x)` stay
  places; `!` and `?` work on every Optional. `!` and `?.` follow `x`
  with nothing between, so `x != y` and `c ? .x : .y` keep their
  meaning. kelvinc left an Optional where a value goes to C's message;
  it says so in Kelvin's now. kc reads `x!`, and refuses a whole
  `d[k]`, which it does not make an Optional yet (P230).

- (217) Agreed details: "teach kc Optional and Result as #217". kc
  makes each `T?` and `Result<T, E>` an enum with values of #215, with
  the names and cases kelvinc gives them, its tokens after the files'.
  kelvinc reads no bare `some(v)`: it passes it to C, whose error says
  `some` is undeclared, so kc refuses it with a word of its own; a
  message of kelvinc's own there waits. With realpath counted (#216),
  kc compiling itself leaves nothing live at exit (P229).

- (216) Agreed details: "fix the realpath counting blind spot as #216",
  which #215 found: since #196 an IO keeps realpath's name and frees it,
  and OS.realpath did before, out of the count's sight, so a program
  that opened files counted fewer live blocks than it had, and passed
  with a leak of as many; the header of tests/asan.sh had called that
  harmless. A program that opens a file and leaks one block counted 0
  live before and counts 1 now; without the renaming, 22 programs fail
  by the new check (P228).

- (215) Agreed details: "teach kc enums with values as #215". A count of
  the sample's allocations found that kc left its global owners for the
  system to take back where kelvinc frees them at exit, which kc now
  does. The count of kc itself found that tests/asan.sh's allocator does
  not count what realpath gives, which an IO keeps since #196 and frees,
  so a program that opens files reports fewer live blocks than it has,
  and a leak of as many would pass: left for a change of its own (P227).

- (214) Agreed details: "teach kc inference of literals as #214", with
  kelvinc's rules, probed for each kind of value. kc's `.count` is an
  int64 where kelvinc's is a size_t, so a variable inferred from one
  differs; kc's own source drops its type only where the value is a
  literal, 34 of them, and its C keeps every type it had (P226).

- (213) Agreed details: "teach kc methods of extend as #213". kelvinc
  calls a method through C's _Generic, since the receiver's type may be
  C's alone; kc always knows it, so it calls T__m itself, the same name,
  as the C contract has it (#208) (P225).

- (212) Agreed details: "teach kc String(n) as #212". kc wrote String(x)
  as KV_STRING_OF(x) already, whose _Generic takes numbers; what it
  lacked: `true` was C's int, written 1, and `println(String(n))` leaked
  the String, which kelvinc holds in a temporary and frees (P224).

- (211) Agreed details: "teach kc Dictionary for symbol tables as
  #211". A lookup makes a String of the name and hashes it; at kc's own
  size both ways take about 7 ms a compile, so what it gives is that a
  name costs the same however many declarations there are (P223).

- (210) Agreed details: "teach kc switch on enums as #210", the first
  of the subset's next steps, its enums C's, of names; an enum with
  values waits. kc is rewritten in it: 57 `let` constants become the
  enums `tkind`, `nkind` and `ykind`, which kelvinc wants declared
  before the structs that hold them (P222).

- (209) Agreed details: "fix the d[$"a"] = 1 bug as #209", the bug a
  probe of #208 found: the temporary of the key wrapped the place, so the
  assignment was to a statement expression, which C does not assign,
  and was not a Dictionary's `set` (P221).

- (208) Agreed details: "write down the C contract as #208", the next
  step of selfhost/README.md. Every claim is read from kelvinc's
  output for probes of each feature, and from its name_functions and
  anon_name. A probe found a bug of kelvinc, left for a change of its
  own: `d[$"a"] = 1`, a Dictionary's entry by a String an expression
  gives, holds the key in a temporary around the place, which C cannot
  assign (P220).

- (207) Agreed details: "teach kc #import <x.h> as C as #207", the next
  step selfhost/README.md listed once libc was allowed (#204). mkdtemp
  waits: it writes its template in place, and a String's `.cstr` is
  const. With C's names unchecked, a Kelvin function used before it is
  written passes kelvinc as C's, and cc says it is undeclared: kc's
  gen.k met it (P219).

- (206) Agreed details: "fix the cells += &c bug as #206", the bug #205
  found. It was not of structs that own alone: `names += &s` of Strings
  and `nested += &xs` of Arrays were the same C, the pointer for the
  value (P218).

- (205) Agreed details: "fix the a[i].f = g() bug as #205", the bug #204
  found when stage1 built by kelvinc with gcc lost three functions of
  kc.k. Testing it found another, left for a change of its own:
  `cells += &c`, an Array of structs that own, as kelvinc's own message
  for `cells += c` suggests, is C that does not compile (P217).

- (204) Agreed details: "Is it possible to self-host kelvin?", with
  selfhost/ and every .k in it, no CI, pure Kelvin (`#import <x> as C`
  is cheating), the prelude, Kelvin modules and `<IO>`, stages as gcc
  has, and the difficulties listed. kc reads the subset it is written
  in: every variable typed, plain structs, String, Array, IO, pointers;
  its C is kelvinc's in form, so the runtime is shared. It found a bug
  of kelvinc: `a[i].f = g()`, g growing a, writes freed memory under
  gcc, C finding the place before the call; kc's source avoids it and
  kc's own C does not have it. Then: "When we self-host, we can still
  depend on libc (or libSystem if you are on macOS) ... Kelvin was born
  to embrace it rather than refusing it": only C of our own is cheating,
  and the README's list says what libc takes off it (P216).

- (203) Agreed details: "fix the return ternary bug as #203", the bug
  #202 found. It was wider than return: kelvinc took `c ? s : t` for a
  value an expression gives, so `var u = c ? s : t` and `eat(c ? s : t)`
  shared s's heap with what freed it, and `println(c ? s : t)` held it in
  a temporary (#187) that freed s. And `xs += c ? x : y` of an Array of
  Strings appended an Array, the ?:'s arm read as the mark of one.
  lambda.k returns its ?: again (P215, rule O12).

- (202) Agreed details: "add `examples/lambda.k` as well which
  implements the lambda calculus ... since we can already handle Unicode,
  lambda is λ, not \ like lame languages like Haskel." A `\` is not
  read, and the message says to write λ. Writing it found a bug of
  kelvinc: `return c ? a : s`, s a local String, gives s without moving
  it, so its cleanup frees what is returned; the example returns s by a
  `return` of its own, and the bug waits for a change of its own (P214).

- (201) Agreed details: "add `example/ski.k` that implements SKI
  combinator logic. It should also include iota and jot." The examples
  are in examples/, so it is examples/ski.k. A term is a node of an
  Array of structs, by index, so a step shares what it does not change;
  ι is S(SI(KS))(KK); Jot starts from I, [w0] = [w]SK, [w1] = S(K[w]).
  Each language's K and S are shown by what they do to variables, and
  SII(SII) stops at its limit. run.sh checks its output (P213).

- (200) Agreed details: "now allow struct p { ... } v; in #inline C
  exports", the case P211 left. Trying it showed that the form went out
  as `extern struct p { ... } v;` already, which C takes; the case it
  missed was `struct p v = {...};`, whose initializer's braces were
  taken for the type's body, so the variable went out defined and the
  program defined it twice. The body is now the `{` right after the tag
  (P212).

- (199) Agreed details: "export Kelvin functions to the .kh for #inline
  C names too", the other way P209 left: a module's .kh had nothing of
  its #inline C, so a program could not call the C it defines. kelvinc
  does not parse C; it reads the block as declarations at its depth 0,
  as P211 says, which covers what a header of C holds (P211).

- (198) Agreed details: "now allow #inline C inside functions too", the
  way P209 left. Kelvin frees a block's owners by C's `cleanup`
  attribute, so a C jump leaves nothing live, which tests/asan.sh checks
  of inline_c_fn.k; a C `return` of an owner would give a freed one, as
  c-interfaces.md says (P210).

- (197) Agreed details: "do #197 with `#inline C { ... }`", after the
  user asked between `inline C { ... }` and `C { ... }`: `C { ... }` is
  already a call of C with a trailing anonymous function, and the `#`
  sets it beside `#import <x.h> as C` as a thing of C and the build, not
  a Kelvin keyword `inline`, which C has for functions. Top level only;
  the `{` on the line of `#inline C`; nothing after the `}` but a
  comment; a brace in a macro counts, as said (P209).

- (196) Agreed details: "now remember the name at open too", the way
  P207 left. The open asks realpath once, so a file removed or renamed
  and removed before anyone asked still answers on FreeBSD (P208).

- (195) Agreed details: "make abspath remember the last name it found",
  the way #194 left for later. kv_io gets `named`, the last name
  kv_io_abspath found, freed when the IO is closed and given up when it
  is taken; a removed file then answers by the name it had on FreeBSD
  too, where abspath asked before (P207).

- (194) Agreed details: "now add a FreeBSD job to CI", with `make test`
  on FreeBSD failing in io_abspath.k and io_stat.k, as #192 foresaw:
  F_KINFO gives no path of a removed file. Keeping the name an IO last
  had would take a field of kv_io; the system's answer stays the answer,
  so the tests take `""` on FreeBSD. The job runs as a user, since
  root opens a file without permission (P206).

- (193) Agreed details: "`git pull && gmake && gmake test` has worked!
  Now add a Makefile that BSD make hands to gmake. Also document that
  `gmake` and `python3` must be installed via `pkg` or ports." GNU make
  reads GNUmakefile before Makefile, so the build is GNUmakefile and
  Makefile is BSD make's alone: its targets and .DEFAULT run
  `$(GMAKE) $@`, with MAKEFLAGS emptied, since BSD make's are not GNU
  make's (P205).

- (192) Agreed details: `gmake` on FreeBSD stopped at runtime/os.c,
  "use of undeclared identifier '_SC_NPROCESSORS_ONLN'" and an implicit
  `getloadavg`: FreeBSD's sys/cdefs.h makes __BSD_VISIBLE 0 where
  _XOPEN_SOURCE is defined, and shows everything where no feature macro
  is, as NetBSD, OpenBSD and DragonFly do, so the BSDs get none. The
  uname test takes "FreeBSD" too. Not yet run on FreeBSD: no machine
  of it here (P204).

- (191) Agreed details: "yes, do #191", after the way of #190, a link
  into `~/.vscode/extensions`, did not install the extension: VS Code
  1.142 loads only the extensions in its own extensions.json and marked
  the link obsolete, to be removed. A `.vsix` is a zip of a manifest and
  the extension's files, so tools/vsix.sh makes one with zip, the name,
  publisher, version and engine taken from package.json, and
  `code --install-extension --force` installs it; tests/grammar.js checks
  the package where zip and unzip are (P203).

- (190) Agreed details: "now add a Kelvin TextMate grammar for VS
  Code", the third way offered in #189. The grammar takes its words
  from the lexer's keywords and the parser's type words, with the full
  names of #151 and the modules' types; a Markdown injection colors
  ```` ```kelvin ```` fences too. Microsoft's TextMate engine would have
  to be downloaded from npm, so tests/grammar.js is a small tokenizer
  of the same rules: it compiles every expression, tokenizes every
  Kelvin file and document example of the repository with nothing left
  open but in the error tests that leave a literal open on purpose, and
  checks the scopes of sample lines (P202).

- (189) Agreed details: "What language do you think kelvin is close? I
  want kelvin codes to syntax-colored." Claude answered Swift, laid over
  C, with Pascal's `^` and `:=`, and that GitHub colors only the
  languages its Linguist knows, which adds one only once hundreds of
  repositories use it; of the three ways offered, the user chose the
  first two: the attribute for files and Swift fences for the examples.
  A grammar of Kelvin's own waits. Swift colors `^`, `:=` and `$/.../`
  as plain operators (P201).

- (188) Agreed details: "now add `+` to `Bytes` too." As String's of
  #183, with what `b += x` takes on the right, a byte among them; a
  byte on the left would make `KV_BYTES_OF` give that many zero bytes,
  so it is refused with `Bytes([n]) + b` to write instead; a String and
  a Bytes stay apart, as `==` keeps them (P200).

- (187) Agreed details: "Those \"bind it to variables first\" is
  annoying. fix it like we have fixed it for `array.map()`", on
  `var words = $"Hello, Kelvin!".split($/\s+/)`. Forty sites refused an
  owner that an expression gives, since nothing would free it; one
  mechanism serves nearly all of them: the expression `E_TEMP` holds
  the owner in a hidden let, as `.map` of #183 held its Array, and frees
  it by `cleanup` when its body is done. A postfix chain collects the
  temporaries its steps make and wraps them when it ends, the last
  innermost; an operator holds its operands in its own list; a loop
  holds what it walks in a let of a block around it. What still asks
  to bind first is what would go wrong with a held owner: a pointer
  into it, which would dangle, and a change to it, which would be lost;
  and an IO's arguments, `+=` on one, and a borrow with no expression
  around it to hold it. Fifteen error tests of the refusals became one
  run test, and three test what stays refused. Rule O9 of
  ownership.md, which still said failures abort, says what #174 made
  them do (P199).

- (186) Agreed details: "now add `.reversed()` and `.reverse()` to
  `Array` too." The pair of #185 without a comparator: in place on a
  var, a new Array otherwise, an Array an expression gives reversed in
  place and handed back (P198).

- (185) Agreed details: "Now add `.sort()` and `.sorted()` to `Array`.
  .sort is mutating and .sorted creates a new sorted array.
  `$[3,2,1,0].sorted{ $0 < $1 }` yields `$[0,1,2,3]`. When the
  comparator is omitted, `<` is used. ascending order, lexicographic if
  string. Compile error if element does not have `<`." The sort is
  written inline, a bottom-up merge sort through one buffer, so that
  each call site compares with its own comparator and no C callback
  takes a context; it is stable, which C's qsort is not. A comparator
  on Strings, `{ $0 < $1 }`, needed `<` on a String, so the four
  orderings are added for Strings and Bytes, by their bytes (P197).

- (184) Agreed details: "Now implement `.filter()` and `.reduce()` for
  `Array` as well." Spelled as Swift has them, since Kelvin's trailing
  functions are Swift's: `reduce` takes its start first, so the
  function trails, `xs.reduce(0) { $0 + $1 }`, where JS writes
  `xs.reduce((a, b) => a + b, 0)`. The map's branch and codegen of
  #182 became one for the three; the function's result needs no
  inference for these, a bool for filter and the start's type for
  reduce, which the context type gives it (P196).

- (183) Agreed details: "This is a little inconvenient. Can you make it
  chainable?" on `xs.map{ $\`${$0}\` }.map{ $0 + "+" }`, and then
  "`.map{ $0 + $"+" }`. `String` must have a `+` operator that
  concats". The map of a temporary holds it in a variable with
  `cleanup`, as an Optional's map holds its own, and frees it when the
  map is done; `+` on a String builds a new String from the left
  side, copied from a variable or taken from an expression, and
  appends the right side by `KV_STRING_APPEND`, borrowed from a
  variable or taken, as `+=` takes it (P195).

- (182) Agreed details: "can we implement generic `.map()` for
  `Array`?" The Optional's and the Result's `.map` of #80 already
  inferred the result type from the function, so the Array's is built
  the same way, a statement expression that appends `f` of each
  element to a new Array; an owner element would be moved out of the
  Array by value, so `f` gets a copy, as `s.match(&re) { }` gives the
  Match it owns. `$0 * 2` gave no type, since arithmetic infers none
  (#47); for a `.map` function alone it now does where the operands
  agree, which an Optional's map gains too, so the error test of #80
  takes a float literal times an integer instead (P194).

- (181) Agreed details: "Let me add self-recursion syntax: `let
  fib(n:int64):int64 { n < 2 ? n : $(n - 2) + $(n - 1) }`. `$()` is JS
  equivalent of `arguments.callee()`. Valid both on global and inner.
  You can rewrite the example as `let fib = { (n:int64):int64 in n < 2
  ? n : $(n - 2) + $(n - 1) }` as well." The parser reads `$(` as the
  function being parsed, by the name and the declaration it has, so
  that an anonymous one, which has no name to call, calls itself too;
  a let that holds an anonymous function is still assigned with `:=`,
  as a reference is (#31), which the example in functions.md writes
  (P193).

- (180) Agreed details: "make inner function definitions behave like a
  toplevel ones", from an error on `let fib(n:i64):i64 { ... }` inside
  main that had told the reader to hold an anonymous function in a let
  instead. A nested function is parsed as a top-level one, hoisted as
  an anonymous function is, before and after the top-level declaration
  around it, and fenced from the locals around it the same way; its
  name is a binding of the block, which the lookup of a function
  follows, so that a block's own hides and ends as a variable's does.
  The error test of #45 that refused the definition is gone, and the
  one of a `var` says what a nested function is written as (P192).

- (179) Agreed details: "now run the longer fuzz and tighten the
  method lookup", the two checks proposed before the version. The
  lookup by a name alone where the receiver's type was not a base type
  had made `text.count` of a `cstr` call `Match.count` (#168), fixed
  there for attributes alone; `method_named` now gives nothing for a
  pointer, an array or a function, and keeps its fallback for a type
  kelvinc cannot see at all. The fuzz, 5000 sources mutated by
  deletion, insertion of Kelvin's tokens, duplication and transposition,
  from the tests, the examples and the modules, crashed and hung
  nothing (P191).

- (178) Agreed details: "now make kelvinc report a global owner made by
  a call", the fifth fix proposed before a release: `let re = $/x/` at
  the top failed in C with "initializer element is not a compile-time
  constant". Every owner's initializer is a call, `KV_STRING_OF`,
  `_kv_array_..._from`, `RegExp.compile`, so the rule is the same for
  all: the parser refuses an initializer on a global owner, and a
  global declared with its type alone is zero, an empty owner, which
  a function fills. The ASan run then counted a global as live at
  exit, so the codegen writes a function that frees the globals and
  has `main` register it with `atexit`, which also makes the frees
  exact for the counter (P190).

- (177) Agreed details: "now add the basic String operations: find,
  has, starts, ends, trim", the fourth fix proposed before a release,
  where strings.md had said "Not yet: searching". The text sought is
  taken as `append` takes it, a `cstr` or `&t`, by a `_Generic` on the
  argument; `find` counts codepoints up to the bytes found; `trim`
  takes off JS's `\s`, as the RegExp engine reads it, so that the two
  agree (P189).

- (176) Agreed details: "now make the documents' examples tests", the
  third fix proposed before a release, after three examples drifted in
  a week. Of 70 blocks, 11 are programs and 59 fragments; a fragment
  is rearranged by its margin, declarations above a main that holds
  the statements, which 19 fragments compiled by at once and 10 more
  after a declaration or an import the example had left out, which the
  pages gained, or a better reading of a margin; 30 are listings of an
  API or sketches with `...`, marked.
  One example was wrong: `extern let labs(n:int64)` conflicts with C's
  `long labs(long)` where `int64` is not `long`. CI's first run found
  another: `lstat` of results.md is hidden by glibc under `-std=c11`,
  which a note had told the reader to work around with a flag; kelvinc
  now defines `_XOPEN_SOURCE 700`, `_DEFAULT_SOURCE` and
  `_DARWIN_C_SOURCE` at the top of the C it writes, as its runtime
  does, so that an imported C header shows its POSIX functions on
  every platform (P188).

- (175) Agreed details: "now add the ASan run over the test
  programs", the second fix proposed before a release: CI's sanitizer
  job instruments kelvinc and libkelvin, not the programs the tests
  make, which is where the double frees of #158 were. The counting
  allocator renames malloc, realloc and free by macros in the runtime,
  the modules and the program, itself compiled without them, and
  reports what is live at exit, which Kelvin's ownership promises is
  nothing. Its first run found one: `${$"tpl"}`, a String an
  expression gives in a plain template, was never freed, where a
  `$`...`` template refused it; both refuse it now. A test that calls
  `SYS.exit` and a free of what `realpath` allocated are not leaks,
  and the script knows them (P187).

- (174) Agreed details: "now make runtime failures exit(1) instead of
  abort()", the first of the fixes proposed before a release: a core on
  Linux and the crash reporter on macOS, for a bad index, are not what
  a user of a program wants. Every failure of the runtime goes through
  one function now, `kv_exit_failure`, with a twin in the engine's
  parser, which kelvinc links without libkelvin; the environment
  variable keeps the old behavior for debugging (P186).

- (173) Agreed details: "add `documents/README.md` that works like a
  TOC of `documents/`." A list by topic with a line each, where the
  table at the end of versusC.md stays the one by detail; a new
  document gets a line in both (P185).

- (172) Agreed details: "I don't get why `Bytes(['\x00', '\x01',
  '\x02', '\x03'])` does not work. make it work. Also split the
  document about Bytes from `strings.md` to `bytes.md`. They look the
  same but they are semantically distinct." A bracket list was no
  value on its own (#48), so `Bytes(` reads one itself, as a compound
  literal of `uint8_t` with its count, a literal out of 0 to 255
  refused; the document moved with the Bytes rows of the table, and
  the links follow (P184).

- (171) Agreed details: "add the `b` flag to RegExp to explicitly
  make it binary mode. with that, each character is a byte so
  `$/[\x80-\xff]/b` matches exactly one byte, which is NOT
  `$/[\u0080-\u00ff]/`. RegExp defaults to Unicode codepoint mode
  where a character is a codepoint. To make it clear, let's add `u`
  flag as well which is actually a no-op." The byte-wise matcher of
  #168 is now the flag's, not the Bytes's: the mode is the pattern's,
  whatever it matches. A String matched with `b` whose match cuts a
  codepoint ends the program where the text is taken, since a String
  holds text; the tests on a Bytes write the flag (P183).

- (170) Agreed details: "now add `b.replace(&re, &bytes)` for `Bytes`
  too." The replacement is a Bytes borrowed or text, as a String's is
  text or a String borrowed, and the `$` patterns read the same over
  bytes, since a replacement without them is the common case and one
  with them costs nothing; the function form gives Bytes for a
  BytesMatch, as a String's gives a String for a Match (P182).

- (169) Agreed details: "now add `s.match(&re)` and `s.split(&re)`
  for `Bytes` too." A `Match` holds Strings, which bytes may not be,
  so a `BytesMatch` holds Bytes, the same otherwise with byte offsets;
  `test` and `search` came along, each an overload by the receiver
  argument on the RegExp and a method on Bytes, over the byte-wise
  matcher of #168 (P181).

- (168) Agreed details: "now add `.escape()` and `.unescape()` with a
  RegExp for `Bytes` too." A Bytes may hold any bytes, so the matcher
  got a byte-wise mode, each byte a codepoint of its value, which makes
  `\xHH` and `[\x80-\xFF]` mean bytes; the result of `escape` is a
  String, so bytes that are not text are `\xHH` whether matched or
  not. `Bytes.unescape(text, &re)` is a function of the type, as the
  prelude's is, which `extend Bytes` may now declare, the call read as
  `Bytes.name(...)` of the program but for the built-in one-argument
  forms. Found on the way: `t.count` of a `cstr` read `Match.count`
  once the module declared it, since the receiver, a pointer, was
  unseen to `method_named`; and the module header dropped a prototype
  whose text another block had, `escape(re)` of String and of Bytes
  (P180).

- (167) Agreed details: "now add `Bytes.unescape()` that reads `\xHH`
  back into a Bytes." Spelled as `Bytes.fromBase64` is, a function of
  the type taking text or a String borrowed, since the bytes are made,
  not read from a Bytes; it reads every escape a String's `unescape`
  reads, a codepoint as its UTF-8, so that a String's `escape` reads
  back into bytes too (P179).

- (166) Agreed details: "now add `s.escape()` for `Bytes` too, as
  `\xHH` form." A byte that is printable ASCII stays, a backslash
  doubles as in a String's, and every other byte is `\xHH`, upper
  case, two digits; the result is a String, text whatever the bytes
  were. Reading bytes back from such text waits for a request, since
  `unescape` gives a String, which `\xFF` could not be (P178).

- (165) Agreed details: "now add `s.unescape(&re)` that only
  unescapes what matches." The two overloads of #164's `escape`, a
  borrow and a value, again; each match goes through the prelude's
  `kv_string_unescape`, so that the escapes read are the same (P177).

- (164) Agreed details: "add `.escape()` to `String` in prelude. with
  no argument, it turn non-ascii code points into `\u{....}` form. You
  can optionally pass `RegExp` where matching characters are escaped,
  like `.escape($/[\p{Emoji}]/)`. `.unescape()` does the opposite." A
  backslash is escaped too, else unescape could not read the text
  back. The RegExp form lives in the module, as two overloads of
  `String`, a borrow and a value, so that the literal in the call
  moves in; `s.escape()` with no argument is then the prelude's,
  which the parser now takes where every method of the program's name
  takes arguments (P176).

- (163) Agreed details: "now add `$/.../` compile-time checking of
  the pattern in kelvinc". The engine's parser of a pattern moved into
  runtime/regexp_parse.c, which needs the Unicode tables alone, data,
  so kelvinc links the two and the lexer checks each literal; an error
  there returns to the lexer by a longjmp instead of ending the
  program, and is reported with the caret at the place in the pattern
  (P175).

- (162) Agreed details: "now add `RegExp.compile` with a String for
  the flags too. Better yet, just let `RegExp(str, flags)` do it." The
  four combinations are overloads of `RegExp.compile`, and functions
  `RegExp(...)` of the same four, as `c64(...)` makes a `c64` in
  math.k. Writing them found that once a function is named as a type,
  `RegExp.compile` in the next overload's body was read as the function
  value, since the name was bound: a type's `T.name(...)` and `T.x`
  now win where the name is both (P174).

- (161) Agreed details: "now add `s.replace(&re)` with a String. I
  thought it was already done... wait, the second arg of `var t =
  s.replace(&re, "$<month>/$1")` was only `cstr` and not `String`?" It
  was a `cstr` alone; the String form borrows it, `&with`, as
  `RegExp.compile` and `Bytes.fromBase64` take a String, and reads its
  text (P173).

- (160) Agreed details: "now add `s.split(&re) { ... }` that iterates
  over each piece." The function form of `split` is the loop of the
  Array form, calling the function with each piece instead of
  appending it, an overload of #158 by its second parameter, as
  `match` got in #159 (P172).

- (159) Agreed details: "now add `s.match(&re) { ... }` that iterates
  over each Match. Also tweak examples a little from doubling the match
  to changing Fahrenheit to Centigrade (since that looks more
  natural)." The function form of `match` is the loop of the Array
  form, calling the function instead of appending, an overload of
  #158 by its second parameter; the examples of `replace` with a
  function, in regexp.md and the tests, now turn `212F` into `100C`
  (P171).

- (158) Agreed details: "can `s.replace(&re, with)` take a function
  for `with` part? if not so, make it so `s.replace(&re) {
  String(f64($0.text[0]) * 2.0) }` works as expected." It could not:
  methods did not overload, so a second `replace` could not share the
  name. Methods now overload as functions do, the call choosing by
  `choose` of #41 among the methods of the name on the receiver's
  type, named in C by their types where they differ. Making it work
  also found two holes: an owner given by value to a method, or to a
  call through a function value, was copied in C and freed twice, which
  the parser now moves as it does into a function; and `String(x)` at
  the start of a statement was read as a C declaration. `String(n)` of
  a number is new (P170).

- (157) Agreed details: the second step of the request of #156,
  "`<RegExp>` yes, regular expression! add `$/regexp/` literal to
  support it but you still need to `#import <RegExp>` to use it.
  support Unicode strings to the level modern JS does PLUS `\X` that
  matches a grapheme cluster." The engine, runtime/regexp.c, parses a
  pattern to a tree, compiles it to a program of words held in a
  Bytes, so that a RegExp is an owner as any Bytes is, and runs it by
  backtracking with an explicit stack; a lookbehind tries each start
  that could end at the point, the farthest first, as JS's backward
  matching prefers the longest. The lexer turns `$/.../flags` into the
  tokens of `RegExp.compile("...", "...")`, with `\`, `"` and `?`
  escaped in the C literal, and the parser says that the literal needs
  the import where no `RegExp` is declared. The Unicode tables grew the
  scripts, the script extensions and JS's binary properties, which
  `uchr` gets as `.script` and `.hasProperty(name)`. A differential
  test of 157 patterns against node agreed on every one, and the
  database's tables are the ones of #156 (P169).

- (156) Agreed details: "let's add two big modules for `String`:
  `<RegExp>` ... and `<UnicodeData>` like python's `unicodedata` which
  adds features missing from the prelude String: `.graphemes` which
  returns a stream of graphemes, unlike String's default which returns
  codepoints; `.normalize()` which returns the normalized String by
  nfc, nfd, nfkc, and nfkd". The user chose to download the database
  from unicode.org, `s.graphemes` as an `Array<String>`, and the whole
  in two steps, UnicodeData first and `<RegExp>` with the `$/.../`
  literal next, each with its tests and documents. The tables are made
  by tools/gen_unicode.py into runtime/unicode_tables.c and
  unicode_names.c, two-level tables of the category, the combining
  class, the grapheme break property and the Indic conjunct break, the
  decompositions and the composition pairs, the case maps and the
  names; the database's own NormalizationTest.txt and
  GraphemeBreakTest.txt are the conformance tests, read through
  `<IO>`. ASan found `$"Straße".fold()` leaking the literal, so a
  method of the program on an owner an expression gives is an error,
  as #154 made a case read and an attribute (P168).

- (155) Agreed details: "Add Base64 handler in the prelude:
  `Bytes.fromBase64()` takes `cstr` or `String` and return `Bytes`.
  Padding can be omitted and URL-safe versions are accepted.
  `b.toBase64()` that returns `String`. You can choose with or without
  paddings, ordinary or URL-safe." Claude asked how the options are
  spelled, and the user chose words, `url` and `nopad`, read inside the
  call as `.is(case)` reads a case. A String goes in as a borrow,
  `&s`, as the prelude's `String(&b)` takes one, so that nothing moves;
  text that is not base64 ends the program, as `b.string()` of bytes
  that are not UTF-8 does, while blanks are skipped (P167).

- (154) Agreed details: found by ASan on the tests of #152: `s[0].string`
  compiled, reading the case of the copy a subscript gives, and the
  copy was never freed, where `.is` of the same value was an error.
  The rule of #99 now covers a case's value and an attribute; a
  codegen that freed such a temporary would be the other way, kept
  for later (P166).

- (152, 153) Agreed details: "Implement SION handler and msgpack
  handler like JSON module." Claude read SION's page and swift-sion's
  source, and the MessagePack spec. A SION dictionary is keyed by any
  value, which Kelvin's Dictionary cannot be, so it is an Array of keys
  and values in turn, with subscripts by a string or an integer key
  and `SION.find` for any; the subscripts give copies, which Kelvin's
  rules bind before a method call. The case names are `boolean`,
  `integer` and `number`, since `bool`, `int` and `double` are words of
  C or Kelvin. MsgPack has no value type of its own: SION's model is
  MessagePack's, as swift-sion has it, so a struct is the functions'
  name. An ext holds its whole encoding, as swift-sion keeps it, so
  that it goes out as it came in (P164, P165).

- (149, 150, 151) Agreed details: "Where is `math.md` which is supposed
  to be in `modules/`? rename `complex64` to `c64` and `complex32`
  `c32`. and keep `complex{64,32}` as an alias. And give the 'fullname'
  to `i{128,64,32,16,8}` `int{128...}`, `u{128...}` `uint{128...}`,
  `f{64,32}` `float{64,32}`." math.md was missing, the math module
  being described in modules.md only: documents/math.md now holds it,
  as json.md holds JSON. Kelvin had no alias, so Claude asked for its
  spelling and the user chose Swift's `typealias`; it is a rewrite of
  the later tokens, as `Self` is, so an alias is the type everywhere at
  no cost. The full names are the lexer's, since they alias keywords
  (P161, P162, P163).

- (148) Agreed details: "rename `complex.k` to `math.k` to give all
  functionalities of `math.h`. sort of like math + cmath. `#include
  <math.h>` therein. add static attributes to `f64` and `f32`,
  including constants like `pi` and `e`. give floating point types
  methods like `f64.sin()` and `f64.exp()`. same there in
  `complex64.sin()` and other complex functions. kelvin is
  multi-dispatch so simple `sin()` or `exp()` should suffice most of the
  cases but if you want to explicitly express which one is used, you can
  distinguish that way. add a computed attribute `.i` to `f{64,32}` and
  `complex{64,32}` that rotates `pi/2` on the gausissian plane. `1.0.i`
  returns `complex64(0.0, 1.0)` for example." Adding `abs(x:f64)` made
  `abs(3)` ambiguous between `i32`, `f64` and `f32`, which `abs(n:i64)`
  settles, since an integer literal is an `i64`; the rule of #41 stays.
  `f32.epsilon` is larger than `f64.epsilon`, as C's are (P160).

- (147) Agreed details: "now add a shared libkM to `kelvinc --lib`
  too". The shared one is for C and other toolchains, as
  `libkelvin.dylib` is: `#import <M>` keeps linking `libkM.a` by its
  path, so a Kelvin program never loads two copies of the runtime.
  The shared library links the shared `libkelvin` and module
  libraries where they exist, and the static ones otherwise, which
  works since every object is built with `-fPIC` (P159).

- (146) Agreed details: "now add a mode that builds a Kelvin file into
  `libkM`". Claude asked whether the header is generated or written by
  hand, and the user chose generated, so that the prototypes always
  match the library's C names. A C function's prototype in the source
  becomes `extern let` in the header, since there a bare prototype is
  the library's; `T.cstr()` keeps its body, being inline and sized by
  its template; a type attribute waits (P158).

- (143, 144, 145) Agreed details: "Let's separate `IO` and `OS` from
  prelude. One day it may be used where IO is not available like
  WASM/WASI environments. you will load them as `#import <IO>`,
  `#import <OS>`. you may split the implementation with header file and
  library like C. let header file's extension `.kh` and libraries
  `libkModule.{a,so,dylyb}`. large modules should be implemented that
  way instead of putting everything in `.k`. unlike C, `.kh` and
  `libkM.` are in the `module` folder. And `#import <M>` loads `M.kh`
  and the linker links the library with `-llibkM`." Claude asked where
  SYS goes, with OS, and whether JSON.k and complex.k become `.kh` +
  `libkM` now, later: that needs a mode of kelvinc that builds a Kelvin
  file into a library. The flag is `-lkM`, since `-l` adds `lib`
  itself, and a `libkM.a` beside the header is linked by its path.
  io.c calls OS's path functions, so `IO.kh` imports `<OS>` and
  `libkIO` links after `libkOS`; `OS.mkstemp` fills an IO, so it asks
  for `#import <IO>` (P155, P156, P157).

- (142) Agreed details: "now make `.x` work in the top-level anonymous
  enum's methods". Every form Claude tried worked but one: `.is(just)`
  at the start of a line after a `let`, which #35 read as `10.is(just)`,
  in any type's method. Claude asked which rule to take, and the user
  chose that a line starting with `.x` is `self.x` wherever there is
  `self`, with a chain over lines inside parentheses; #35 holds where
  there is no `self` (P154).

- (140, 141) Agreed details: "Also note inside `extend T`, `T` can also
  be referred as `Self` like swift. That goes to `let T.meth(){...}`.
  in `...` `Self` refers to `T`." and "Just to be more explicit
  functions without return values (C's void f()...), you can optionally
  add `:()`". Claude read `Self` in every member of `T`, the attributes,
  subscripts and functions of the type too, and where `T`'s name goes
  as well as where a type goes, since Swift's does both; a type with no
  tag keeps `Self` as a type only. `:()` is read wherever a result is
  written, and `:():R` keeps its old reading (P152, P153).

- (138, 139) Agreed details: "now make a method reject changing self.
  Also make `.attr` mean `self.attr` in the method definitions." #138
  ends #27's "self is a mutable copy", which changed only the method's
  own copy: three programs that moved a copy now write `var p = self`.
  #139 is read in every body with `self`, the attributes, setters and
  subscripts too, since their bodies are a method's. Claude chose how
  `.x` meets the rule of #35 that a `.member` on a new line goes on with
  the expression: that stays, except that a new line that sets a
  member starts a statement where there is self, so a setter's lines
  `.n = v` and `.xs += v` work; `self.f()` starts a line with a call
  (P150, P151).

- (137) Agreed details: "now make a let attribute's getter reject
  changing self". Found while testing #136, whose getters already
  reject it: an attribute's getter changed its own copy of `self`, which
  did no harm and meant nothing. A `var` attribute's getter is a getter
  too, so it follows; the setter and methods are unchanged (P149).

- (136) Agreed details: "now add subscripts inside `extend T {}`".
  Claude asked for the spelling; the user chose `let [](i:i64):R { }`
  for a read-only one and `var [](...) { get { } set(v) { } }` for one
  that is also written, as Swift's `subscript` with Kelvin's `let` and
  `var` of attributes (#131, #132), and `let T[](...)` alone. A getter
  reads `self` and never changes it; a setter changes the caller's var,
  which is a `var`. Overloads are chosen by the indices' count, then
  their types, a literal as the type it infers to first (P148).

- (135) Agreed details: "now add operators inside `extend T {}` as
  `static let +`". The spelling is the user's, Swift's `static func +`:
  an operator is no method, since it has no self, so it is `static` in
  extend, and the same Decl as the top level's `let +`. As in Swift, it
  takes a `T` as one of its values (P147).

- (134) Agreed details: found while testing #132, whose setters assign
  to members of `self`: `p.name = v` of a member that owns was C's
  assignment, so the old value was never freed, in any program, not
  only in a setter. It now goes through the type's `_assign`, the new
  value first, as an owner local's assignment does (#128); an IO is the
  one owner with no `_assign`, and keeps C's (P146).

- (130, 131, 132, 133) Agreed details: "add `extend T {}` that does
  `extension T {}` in Swift where `var` or `let` are instance attributes
  and `static var` or `static let` are type attributes. Also add
  document about it as `attributes.md`. Document both `let T.f {}` and
  `extend { let f {} }`. If you like, rewrite existing codes in the repo
  with `extend T {}`." Then: "we already have properties.md. aggregate
  attributes.md to that". Kelvin had methods and functions of a type
  but no attribute read without parentheses and no value of a type;
  asked, the user chose all three kinds of member, and for a `var`
  instance attribute, a computed one with a setter, over an error that
  no storage is added. So: `extend` groups the members (#130); `let
  T.x:R { }` is a computed attribute (#131); `var T.x:R { get set }`
  has a setter, whose `self` is the caller's var (#132); `static let`
  and `static var` are type attributes, globals of the type (#133).
  Each member has its form alone, naming `T`, and its form in extend,
  the same thing; both are documented in properties.md, not a new
  document. examples/shapes.k, examples/linkedlist.k and the functions
  of modules/JSON.k were rewritten with `extend`, their output
  unchanged (P142 to P145).

- (129) Agreed details: "also add `.pretty(n)` to `JSON.stringify`'s
  space", read as a number for the space, as `.pretty(n)` takes one and
  JS's `JSON.stringify` does: two overloads in modules/JSON.k, beside
  the text ones, with the number clamped to 0 to 10; 0 gives compact
  text, as in JS (P141).

- (128) Agreed details: "now add `+=` on an enum with values via its
  operator". `x += y` already became `x = x + y` through the
  program's operator, by the rule of #42, but for an enum that owns it
  gave the wrong value: `x = v` of an owning struct or enum freed `x`
  before it evaluated `v`, so `v` read an emptied `x`. That broke a
  plain `x = x + y` and `x = f(x)` as well; it now goes through the
  type's `_kv_T_assign` of #117, which takes the value first (P140).

- (127) Agreed details: "now add `.pretty` with a custom indent width".
  Asked how the width is given, the user chose `x.pretty(n)`, a number
  of spaces, over text as `JSON.stringify` takes or a program-wide
  setting. 0 to 10 as JS clamps it; 0 still breaks the lines; plain
  `.pretty` stays two (P139).

- (126) Agreed details: "now add `${d}.pretty` in a template", read as
  `${d.pretty}`, the indented text inside a template; `${d}.pretty` as
  written is the value's text followed by ".pretty". It went through as
  a String that nothing freed in `` `...` ``, and was refused in
  `` $`...` ``; it now takes the printer at the indented level, as
  `${xs}` takes it on one line (#125) (P138).

- (125) Agreed details: "now add `${xs}` of an Array in a template".
  The printer of #123 serves a Dictionary and a Set the same way, so all
  three, which a template had refused. A template's text has bounded
  room, kept on the stack, so the text goes through a String freed at
  once and is cut as a string value is, past `KV_TEMPLATE_STR` bytes
  with `...`; `` $`...` ``, a String, takes it whole (P137).

- (124) Agreed details: from the same request, "add `print` and
  `println` and option to pretty-print values in `()`, `[]`, and `{}`,
  indented and line-fed". Asked how the option is spelled, the user
  chose a property, `x.pretty`, over `pprint` functions or a leading
  option argument: printed where it stands by `print`, and a `String`
  elsewhere. Each non-empty `[]` and `{}` breaks, an item a line, two
  spaces a level; a case's `()` holds one value, so it stays on its
  line and what it holds breaks; a type's own `T.cstr()` stays as it
  is (P136).

- (123) Agreed details: "now give println of a struct its .cstr text and
  Array's elements in `[]` and `Dictionary` key-value pairs in `{}`".
  The first part was done by #122, in another session the same day;
  this one extends it to an `Array`, a `Dictionary` and a `Set`, which
  were refused, and to a struct that holds them, which #122's bounded
  `.cstr` could not show. kelvinc writes a printer for each type that
  streams the text, so `print` shows everything at any length; `.cstr`
  and templates keep their room. Asked how text inside a value shows,
  the user chose quoted, `["a", "b"]` and `{"ann": 31}`, which also
  quotes a String inside a struct's or an enum's `.cstr`,
  `{name: "held"}`, `err("empty")`: sixteen tests' expected text
  changed so. A float inside a value keeps `.cstr`'s form, `11`, not
  print's `11.0`. Three error tests that `print(xs)` is refused were
  removed (P135).

- (122) Agreed details: `println(p)` of a struct, or of an enum with
  values, passed kelvinc and failed in C, as a struct given to the
  prelude's `const void *` for addresses, while `${p}` showed it.
  Asked whether kelvinc should refuse it with a hint to `p.cstr`, or
  show its `.cstr` text, the user chose the text, so `print` agrees
  with a template; a value kelvinc cannot see as a struct stays a C
  error, as it is in a template (P134).

- (121) Agreed details: "now add methods and operators on an enum with
  no tag". Asked how a method names a receiver that has no name, the
  user chose its spelling, `let enum{nothing, just: i64}.orZero()`,
  over a type alias or operators alone; the same form serves a struct
  or a union with no tag. Found on the way: an operator the program
  defined for any enum with values, named or not, was never reached,
  since the check of `==` (#79) refused every other operator first; it
  now goes to the program's operators, and `==` and `!=` too when the
  program writes them for the type. A function of the type, `static
  let`, is refused for a type with no tag, which has no name to call
  it by (P133).

- (120) Agreed details: "now add an anonymous `enum` with values at
  the top level". A nameless enum already went where a type goes; the
  top-level declaration had no meaning and gave a confusing error, and
  a nameless type had no `T.n(x)` to make a value by. Asked, the user
  chose C's reading: as `enum { A, B }` declares A and B, the cases
  become words of the program, `red` a value and `rgb({1, 2, 3})` a
  maker, so a declaration infers the type from them. The words that
  Result and Optional own, `ok`, `err`, `none`, `some`, a function's
  name and an enumerator's are refused as case names, each way round,
  since a word that two things claim is no word (P132).

- (119) Agreed details: "now add a `switch` that binds the case's
  value". Swift's `case .n(let x)` in the spelling `if let n(x) = e`
  already has (#78): `case n(x):`, with `x` a let the enum still owns,
  as a loop's element is, so it is borrowed or copied, not moved. A
  case that binds stands alone, since one body for two cases could not
  say which value `x` is; a case with no value binds nothing, and says
  so. The same name may serve several cases, each case being a block
  of its own in C already (#63). A switch on a value no place holds, a
  call's result, reads it once into a hidden variable (P131).

- (118) Agreed details: "now add a longer delimiter for `"""` inside
  `"""`. also use: `"""` / multi-line quotation / `"""` instead of
  `"""multi-line quotation"""` to emphasize it is truly multi-line
  through entire documents." The delimiter is a run of three or more
  quotes, closed by a run as long, as a Markdown fence is; the extra
  quotes of a longer closing run are text, so a text may end in a
  quote. For the form on its own lines, Swift's rules, which make it
  read as the user asked: the line break after the opening run and the
  one before the closing run are not text, and the indentation of the
  closing run comes off the start of each line, so the text sits at the
  code's depth; a line with less is kept as it is. The inline form
  `"""as it is"""` stays, with everything between the quotes (P130).

- (117) Agreed details: "now add `j["key"]` and `j[i]` straight on a
  JSON". Not JSON's alone: any enum with values that holds a Dictionary
  or an Array is indexed through that case, text choosing the
  Dictionary and an integer the Array, and what follows is the case's
  own indexing, a place, checked. A JSON that is no object, a missing
  key and an index out of range end the program as `j.object["k"]`
  would, so no error case is made on the way, and `j["a"]["b"] = v`
  writes into the tree. Found on the way: `xs[i] = v` of an Array of
  an enum with values, or of a struct that owns, wanted a `_kv_T_assign`
  that was never written; it is now (P129).

- (116) Agreed details: "now fix the wart: `none` as an arm of `?:`".
  Three things: the wrapping a `return`, a declaration or a body gives
  a `T?` now goes into each arm of a `?:`, so `none` and a `T` are
  wrapped where they stand, and a Result's `ok(v)` and `err(e)` the
  same; an arm beside one that is a `T?` or a Result is wrapped to it,
  as `==` wraps its other side (#79), so the type is inferred; and an
  else arm that starts with a type's name and `<` or `(`,
  `Optional<i64>(n)`, `Set<i64>()`, `Bytes(s)`, is a value, where the
  parser read `v : Optional<i64>` as an annotation (P128).

- (115) Agreed details: "Also add the multi-line, non-interpolating `"""`
  a la python, et al. That may quote JSON-like text more easily." The
  text between the `"""` is taken as it is, over any number of lines:
  no escapes either, since a JSON text holds `\"` and `\n` that must
  reach the parser as two characters, and no `${...}`; a `"""` cannot
  be inside. The lexer writes it as one C string literal, so it is a
  `cstr` as any literal, joins with a neighbour, and `$"""..."""`
  makes a String (P127).

- (114) Agreed details: "now fix the wart: `):JSON? in` in an anonymous
  function." Two faults: the lookahead that tells a signature from a
  block scanned a base type's suffixes with a loop of its own that
  stopped at `?`, and read `in` as an operand after a `?`, since `in`
  is an identifier token; and a one-expression body was returned
  without the wrapping a `return` statement gives a `T?` result, so
  `none` reached C as a name. Both now go the way of `return` (P126).

- (113) Agreed details: "Add JSON handler as an importable module as
  `#import <JSON>`. define `union JSON` like `enum SION` in swift-sion:
  bool, f64, String, Array<JSON> or Dictionary<String, JSON>. is
  nullptr fit for null of JSON? `JSON.parse(str)` takes `cstr` or
  `String` and return `JSON`. `JSON.stringifiy(json, replacer, space)`
  like JS. space is either cstr or String." The union is an enum with
  values, which holds an Array and a Dictionary of itself already
  (#61); its `null` is a case carrying nothing, since `nullptr` is a
  pointer and a value of JSON is not; the case is `boolean`, since
  `bool` names a type. Asked how a bad text should come back, the user
  chose a case `error: String`, as SION has `Error`, over ending the
  program or a Result, so `parse` is straight. `stringify` takes `&j`,
  since passing an owner moves it; its replacer is a function
  `(key:cstr, value:const JSON^):JSON?`, `none` for JS's `undefined`;
  `space` a cstr or a borrowed String, cut to 10 characters as JS
  cuts it. Numbers are written as JS writes them, by `snprintf` at 15,
  16 and 17 digits until the text reads back (P125).

- (112) Agreed details: from "Add JSON handler as an importable module
  as `#import <JSON>`": the lexer took a header name without `.k` for
  C's, and asked for `as C`; a name with no extension at all is now a
  Kelvin file, `name.k`, found as `<name.k>` is (P124).

- (111) Agreed details: "`JSON.parse(str)`", "`JSON.stringify(json,
  replacer, space)` like JS", from the same request. Kelvin had `T.case(v)`
  for enums and methods with `self`, but no function called by a type's
  name. Claude offered three spellings and the user chose Swift's:
  `static let T.name(...)`, where `static` on a dotted name means the
  type's function, not C's storage; a plain `let T.name()` stays a
  method. `self` in such a function, calling it on a value, and
  declaring it on a built-in type are errors that say so. The one use
  of a C-static method, in a regression test of #18, became a plain
  method (P123).

- (110) Agreed details: "now add `IO.popen`, `IO.exec` and `IO.pipe()`
  straight too". As #109: the shape the user chose there, an IO holding
  its error, serves a process the same, `f.error` what the exec failed
  with, `ENOENT` for a program not found or a directory not entered,
  and such an IO as one that did not open, `f.pid` -1. A pipe's two
  ends are a struct of two IOs, so the error of a pipe that could not
  be made is in both. With this, nothing of `IO` is a Result any more
  (P122).

- (109) Agreed details: "now add `IO(path, mode)` straight too". Claude
  noted that the open is the one call on an IO that checks a path, as
  `OS.lstat` does, so something else must carry `ENOENT`, and offered
  three shapes; the user chose an IO holding its error: `f.error` is
  the open's `errno`, 0 when it opened, and the IO is otherwise as a
  closed one, `f.fd` -1, whole-file reads and attributes none, so a
  program asks `f.error` where a file may be missing and passes it up
  as `err(f.error)`. Reading such an IO by `f.lines` or `f.read(n)`,
  or writing to it, ends the program as of a closed IO, now with the
  path and the reason in the message, so a program that did not ask
  still learns why. `try IO(...)` is an error. `IO.popen`, `IO.exec`
  and `IO.pipe()` keep their Results until asked (P121).

- (108) Agreed details: "now add `f.chmod` and the other operations
  straight too". An operation can fail for real on an open file, with
  `EPERM` of a file one does not own, so something must say whether
  it was done: a `bool`, the form `seek` and `kill` already had, and
  no `errno`, which `OS`'s of the same path still tells. Through the
  descriptor where the system can, `fchmod`, `fchown`, `ftruncate`,
  `futimens`, so a file renamed or removed behind the IO is still
  worked on; `remove` and `rename` need a name, the path while it is
  there, else the descriptor's of #105. False of a pipe, a stream, a
  closed IO (P120).

- (107) Agreed details: "now add `f.bytes` and `f.string` straight
  too". As #104 and #106: the file was there to open, so what reading
  it gives needs no Result. A stream that stops answering, a directory
  on Linux, gives what was read before, with the error cleared. The
  one case that was a real err, `EILSEQ` of text that is not UTF-8,
  now ends the program with a message, as a line of `f.lines` and
  `String(&b)` of a Bytes already did: a program that may meet such
  text reads `f.bytes` and asks `b.isUTF8`. `try f.string` is an error,
  as of any non-variant (P119).

- (106) Agreed details: "now add `f.stat` straight to the rest of
  `IO`'s attributes". The attributes still wrapped were `listdir`,
  `walk` and `glob`, and they follow #104: the directory was there to
  open, so an Array straight. They work in the path while a stat of it
  answers, else in the descriptor's name of #105, so a renamed
  directory answers with absolute paths; a file, a pipe, a closed IO
  give an empty Array, where `OS.listdir` of the same would give
  `ENOTDIR`, since `f.isdir` tells that already. What stays as it was:
  `f.chmod`, `f.chown`, `f.truncate`, `f.utime`, `f.touch`, `f.remove`
  and `f.rename` are operations, 0 or `errno`, and fail for real on an
  open file one does not own; `f.bytes` and `f.string` are contents,
  with `EISDIR` and `EILSEQ` to tell. An Array an expression gives
  stays an owner to bind first, by the rule of #54 (P118).

- (105) Agreed details: "now add `f.abspath` via the descriptor when the
  path is gone". The path first, as #104 had it; then what the system
  knows of the descriptor, macOS's `F_GETPATH` and Linux's
  `/proc/self/fd`, with Linux's ` (deleted)` suffix cut so a removed
  file answers by the name it had on both; a name that does not start
  with `/`, a pipe's `pipe:[n]`, counts as none. Elsewhere, and of a
  pipe or a closed IO, `""` as before (P117).

- (104) Agreed details: "now make `f.stat` give a `Stat` straight. Other
  file-attribute related methods follow the suite. Note `OS.lstat(path)`
  is a completely different story because it needs to check the
  accessibility of `path` for each invocation that may fail." The
  user's reasoning: once `IO(path, mode)` is `ok(IO)`, the file is
  there, so a Result around what the open file answers makes every
  caller unwrap an error that cannot come. `f.stat` goes through the
  descriptor, where fstat has no realistic failure; `f.lstat` and
  `f.abspath` go by the path, which can be gone or absent, so they fall
  back to the open file's stat and to `""` rather than to a case;
  `f.isdir` and `f.isfile` read the descriptor's stat too, so they agree
  with `f.stat` for a file moved while open; `f.islink` and `f.exists`
  stay the path's, as the bools they were (P116).

- (103) Agreed details: "now add `IO.isatty` and `IO.strerror` for
  its err to `IO`". `isatty` as a property of an IO, of its descriptor,
  false once closed; `strerror` as `IO.strerror(code)`, the same call
  as `OS.strerror`, since a program that opens files reads their errs
  from `IO` and should not have to know `OS` for the message (P115).

- (102) Agreed details: "now add what Python's `os` has beyond these to
  `OS`". What one C call gives, Kelvinized as before: `access` as
  three `bool`s rather than a mode to mask; `uname`, `splitext`,
  `loadavg`, `terminalsize` and `diskusage` as structs spelled as
  themselves, all now made by one maker from their spelling; the path
  helpers with Python's edge cases; what needs root or a scheduler
  left out (P114).

- (101) Agreed details: "Adopt some of those in `OS` to `IO`,
  especially those related to directory manipulations and file
  permissions: `f = try IO("./foo"); f.abspath` [...] `f.path` simply
  returns `"./foo"`; `d = try IO("."); for item in listdir {...}`;
  `f.stat` that returns `OS.stat(f.path)`; and the list goes on". The
  IO keeps the path it was opened with; what C does on a descriptor,
  `fstat`, `fchmod`, `fchown`, `ftruncate`, is done on the open file,
  the rest on the path; `rename` changes the IO's path, so it needs a
  var, as `close` does; `IO(path)` with no mode reads, a directory
  too (P113).

- (100) Agreed details: "now add setting the signal of `IO.popen`'s
  pid". The pid a `popen` child has is C's secret, so `IO.popen` no
  longer uses `popen`: it is `IO.exec` of `/bin/sh -c command`, which
  is what `popen` does underneath, and so has a pid, a `kill`, and the
  same `status` and `signal` as before (P112).

- (99) Agreed details: "now add a file's owner to `OS`". `chown` and
  `lchown` as C has them, with -1 to leave an id; the names beside
  them, since `stat` gives numbers and a program shows names, as
  `OS.user` already did for the program's own; the names as Strings,
  copied out, after CI's glibc showed a `cstr` into C's static storage
  overwritten by the next lookup (P111).

- (98) Agreed details: "now add setting a file's times to `OS`". The
  times as `stat` reads them, `f64` seconds, so that what one call
  gives the other takes; `touch` beside it, since setting both times
  to now on a file that may not exist is the usual want (P110).

- (97) Agreed details: "now add temporary files made for you to `OS`".
  Python's `mkstemp` and `mkdtemp` by name; the file as an IO and its
  path together in a struct the Result owns, since a temporary file is
  both written and named for later; the prefix alone, the six X and
  the directory supplied, `tmpdir` unless the prefix says where (P109).

- (96) Agreed details: "now add walking a tree and globbing to `OS`".
  `walk` as one flat Array of paths rather than Python's triples, since
  an Array is what Kelvin walks with `for`, and `OS.isdir` and
  `OS.stat` tell the kinds apart; depth first with each level sorted,
  so the order is the one `find` prints and is the same on every
  system; `glob` as POSIX has it, with no match an empty Array rather
  than an err (P108).

- (95) Agreed details: "So many methods are missing!! Where is
  `.lstat(path)`, for instance?" The rest of Python's `os` and
  `os.path` that C gives plainly: `stat` as a struct of C's fields,
  Kelvinized to `i64`, `i32`, `f64` and three `bool`s read off the
  mode, the same struct for `stat` and `lstat`; `basename`, `dirname`
  and `join` with Python's edge cases; the ids, the user and host,
  time and sleep. Walking, globbing and temporary files, which need
  more than one call, are left for later (P107).

- (94) Agreed details: "Add `OS` and `SYS` to prelude. A la Python but
  as a part of prelude you don't have to `#import`." The names and the
  split are Python's; what each gives is Kelvin's: a `bool` where C
  answers yes or no, 0 or `errno` where C only fails, an Optional
  where a thing may be absent, a Result where a value or an `errno`
  comes back; `listdir` sorts, since `readdir`'s order is none. For
  `SYS.argv`, kelvinc's C `main` always takes `argc` and `argv` and
  hands them to the runtime first (P106).

- (93) Agreed details: "now add an environment made from nothing to
  `IO.exec`". A fifth argument, a bool, since Kelvin has no named
  arguments and the entries stay the fourth; in the child, `environ`
  becomes the entries' vector before `execvp`, so the program is found
  on that environment's PATH, which the document says, rather than on
  the parent's (P105).

- (92) Agreed details: "now add a process's environment and working
  directory to `IO`". Two more arguments of `IO.exec`, in that order,
  since a directory is the commoner want; the entries added to the
  parent's environment rather than replacing it, as `putenv` has it,
  which is what a caller setting one variable means; a `chdir` that
  fails reported through the same pipe as a failing exec (P104).

- (91) Agreed details: "now add sending a signal to a process to `IO`".
  Only a process `IO.exec` started has a pid to send to, since `popen`
  keeps its child's to itself, so `kill` is `false` there and `pid` -1,
  which the document says; the signal numbers are C's, as `<signal.h>`
  names them (P103).

- (90) Agreed details: "now add running a process without the shell
  to `IO`". The arguments as a list, since there is no shell to split
  one text, which the message says; the program found on the PATH as
  `execvp` finds it, and the exec's failure reported to the parent
  through a pipe closed on exec, so that a missing program is `ENOENT`
  as a missing file is, not a child that exits 127 (P102).

- (89) Agreed details: "now add a process's signal to `IO`". Beside
  `status`, from the same wait status `pclose` gives, so that a
  process's end is read as two numbers, the exit code and the signal,
  one of them meaningful (P101).

- (88) Agreed details: "Instead of adding reading a number in a base to
  `IO`, let us get rid of them. `scanf()` is evil and error-prone and
  you can always read line or whole file string and apply i64(line) on
  it." The readers of #85 that went through `fscanf` are gone, two days
  after they came; `f.byte` stays. So that `i64(line)` reads as the
  user wrote it, the converters now take a String or a Bytes, through
  its text, as they take a `cstr` (P100).

- (87) Agreed details: "now add opening a pipe or a process to `IO`".
  A process by `popen`'s name, since it runs a shell command as
  `popen` does, and its exit code as `status` once closed, where the
  kind of an IO decides `pclose` over `fclose`; a pipe as its two ends
  in an untagged struct, `{reader: IO, writer: IO}`, which a Result
  holds and which frees both (P99).

- (86) Agreed details: "now add opening with a file descriptor to
  `IO`". The same constructor, told by the first argument's type, as
  `Bytes(n)` and `Bytes(text)` are told; owned, as C's `fdopen` makes
  `fclose` close the descriptor; `f.fd` beside it, since a descriptor
  is what C's own calls take, and an IO should give one back (P98).

- (85) Agreed details: "now add reading a single byte and a number to
  `IO`". An Optional, since the end and a missing number are the usual
  outcomes, not errors; `.i64` and `.f64` as the names of the text
  converters, read as `scanf` reads, so a `.i32` says to read an `.i64`
  and convert (P97).

- (84) Agreed details: "now add `.eof` and seeking to `IO`". `seek(n)`
  counts from the start alone, since C's `SEEK_CUR` and `SEEK_END` are
  stdio's names, which an IO does without: a relative or end-relative
  position is `f.position + k` or `f.count - k`, with `count` the
  length as a Bytes's is; `eof` is C's `feof`, set by a read, and the
  document says so (P96).

- (83) Agreed details: "now add `print` and `println` to `IO`". The
  prelude's printers now write to a FILE, with `print` the stdout case,
  so an IO shows every type as `print` does, with the same 16-value
  limit and the same refusal of a function (P95).

- (82) Agreed details: "Let us add Kelvinized version of stdio to the
  prelude": `let f = try IO(path, mode)` with a `cstr` or a `String`
  path, `f.bytes` the content or an err (as reading a directory fails),
  `f.string` the UTF-8 or a failure, `for bytes in f.read(nbytes) {}`,
  `for line in f.lines {}`, `IO.stdin`, `IO.stdout`, `IO.stderr`, and an
  IO a dynamic object like a String, closed when its scope ends. Added
  beside them: `f.write(x)`, `f.flush()` and `f.close()`, since the
  standard streams are of no use without writing; the err is `errno`,
  an `i32`, as results.md's practice has it, with `EILSEQ` for text
  that is not UTF-8; a line that is not UTF-8 ends the program, as a
  String made of it would (P94).

- (81) Agreed details: "now add `flatMap` on `Result` and `Optional`".
  Swift's `flatMap`: the function gives the Optional or Result itself,
  so the result is not wrapped, and a Result's function must give the
  same `err` type, since the err carries over unchanged. On the way, a
  function whose one expression gives an owner, as `{ positive($0) }`,
  was refused as dropping it; the check now waits for the body's end
  (P93).

- (80) Agreed details: "now add mapping on `Result` and `Optional`".
  Swift's `map` and `mapError`, as `map` and `mapErr`: Kelvin's
  anonymous functions have no closures, so `$0` is the value and the
  rest comes from globals; the result type is the body's one
  expression's where kelvinc sees it, which is how `let` infers, so
  `{ $0 * 2 }` says to write the result or convert, as `let` would
  (P92). `flatMap` is left for later.

- (79) Agreed details: "now add `==` on `Result` and `Optional`". The
  same case and equal values, as Swift's Equatable conformance gives;
  the other side is wrapped as where a Result or an Optional is
  expected, so `x == none` and `r == 42` read as they sound; a value
  with no `==` of its own leaves the Result without one, which the
  message says; and since the same derived function serves every enum
  with values, `json == json` comes with it (P91).

- (78) Agreed details: "now add `if let` of the error". Written as a
  case pattern, `if let err(e) = r`, beside `if let v = r`, since
  Kelvin spells a Result's cases as words (`ok(v)`, `err(e)`) and has
  no leading dot; the same form names a case of any enum with values,
  `if let n(x) = j`, which is the same code (P90).

- (77) Agreed details: "now make `return {0, 0}` wrap into a
  `Result<point, U>`". A `return` of a list reads the result type as a
  declaration reads its type, so the same change makes `return {0, 0}`
  of a plain `point` work, which also was an error; the user's case is
  the wrapped one (P89).

- (76) Agreed details: "now add `try`, passing an `err` up", after the
  practice in examples/results.k, where the hand-written form was `if
  r.is(err) { return err(r.err) }`. `try` is a prefix expression, so it
  goes where a value goes, `let n = try f()`, `return try f(a) + try
  f(b)`, and alone as a statement; the err passes up as it is, so the
  function's `err` type must be the same, and an Optional's `none`
  passes only to an Optional (P88).

- (74, 75) Agreed details: "now add `if let`, binding an optional's
  value when present. Also implement a `Result<T,U>` as a smart union
  as `{ ok:T, err:U }` and reimplement `Optional<T>` as its special
  type." Both now come from one maker of variants: `Result<T, U>` with
  `ok` and `err`, and `Optional<T>` with `none` and `some`, the value
  case `ok` or `some`; `ok(v)` and `err(e)` are words where a Result is
  expected, as `none` is where an Optional is, since Kelvin has no
  leading dot; `if let` binds the value case of either and keeps it the
  variant's, as a loop's element is (P86, P87).

- (39) Agreed details: "implement the template literal a la JS.
  backquote up to backquote. multi-line. `${expression}` is substituted
  with the string representation of `expression`". The user chose that
  the text is on the heap, freed automatically when the enclosing block
  ends (any length, and the same lifetime as `.cstr` text), and that
  `${x}` is shown as `print` shows it.

- (38) Agreed details: "When you add hidden variables when translating
  to C, `kv_` doesn't look automatic enough. use `_kv_` instead and
  trailing word should be the one the variable is derived.
  `_kv_varname_text[36]` instead of `kv_text3[36]` or when you resort the
  the latter style, count the prefix number from `0` instead of `1`."
  The user chose: everything kelvinc writes is renamed, file-scope names
  too (C reserves file-scope names starting with `_`, which gcc and clang
  accept; clang warns only under `-Wreserved-identifier`), while the
  runtime's API keeps `kv_`; a name that repeats in a function gets 1,
  2, ..., and one with no source counts from 0 (`_kv_text0`).

- (37) Agreed details: "Add `p.addr` to pointer types which always
  returns its own numerical value. `p.hex` returns its stringified value
  in a printf format `%016p` or `%08p` depending on the size of the
  pointer." The user also linked a claude.ai conversation, which needs a
  sign-in, so Claude did not read it. Since `%016p` counts the `0x` in
  its width (`0x0000016ee86888`, 14 digits) and the 0 flag with `%p` is
  undefined in C, Claude asked. The user chose `uintptr_t` for `.addr`;
  `0x` and all the digits for `.hex` (`0x000000016ee86888`, 8 digits on
  a 32-bit target); and both properties for every pointer and function
  value, with an array an error, `.dec`, `.oct` and `.bin` of a pointer
  still errors, and `.cstr` unchanged.

- (36) Agreed details: "add numerical string to numerical value
  converters as `i64("42")`, `"42".i64` and such. You can add base as
  `i32("755",8)`. You can use C's `strtol` (and friends) and `strtod`."
  The user chose that strings parse (a literal, `cstr`, `u8^`/`i8^`, C's
  `char *` through `_Generic`) while numbers and other pointers convert
  as before; that bad text is read the way `strtol` reads it (the
  longest number, else 0), with out-of-range values clamped to the type's
  limits; and that the base is 10 unless given, with Kelvin's own
  prefixes accepted when a base is.

- (19) Agreed details: the user's example `buffer := malloc(8 * 1024):i64`
  was a typo for `:i64^`, and `v:T` keeps meaning `v as T`.
  - Declarations of references use `:=` too (`p:i32^ := &x`, or
    `buffer := ...:i64^`, which infers `i64^`).
  - Pointer arithmetic (`p += 1`) stays as in C (`p++` went with #26).
  - Enforcement is best effort. kelvinc checks a target whose type it can
    see: a variable, parameter or `self`, a field of a Kelvin struct,
    `p^`, `a[i]`, and combinations of these. `=` on a reference and `:=`
    on a value are errors. Targets of unknown type, such as C typedef
    types, fields of C structs and call results, are not checked.
  - `:=` is an assignment like `=`, emitted as C's `=`, and usable in a
    `for` clause (`for (var n: struct node^ := list; n != nullptr;
    n := n^.next)` since #27). Like `=`, it declared a name that was not
    declared yet, until #27; since #26 it is a statement, not a value.

- (20) The user's words: "abolish type `void`. to mean C's `void *`,
  introduce `any^`", then "not `any`. it must be `any^`. Introduce
  `nullptr` to mean `(void *)0`. `ptr:any^;` means `ptr := nullptr`".
  - `any` is valid only behind `^`. `void` is rejected with a hint
    everywhere.
  - `nullptr` is a keyword, emitted as `((void *)0)`, and infers `any^`.
  - A function without a result still omits `: type`.

- (21) Agreed details:
  - The text comes back as `u8^` in a buffer on the caller's stack, sized
    in advance from the type: no heap.
  - `.hex`, `.oct` and `.bin` prefix `0x`, `0o` and `0b`.
  - Signed integers always carry a sign (`+42`, `-0x2a`), which tells them
    from unsigned ones (`42`, `0x2a`).
  - `f32`/`f64` `.dec` is `%.17g` style (`%.9g` for `f32`), and `.hex` is
    `%a`, both always signed.
  - For `.size`, a field wins when unsure. `.size` is `sizeof` only where
    kelvinc sees the receiver is not a struct (a scalar, pointer or array),
    or is a Kelvin struct without a `size` field. On C structs and unknown
    types, `.size` stays a field access.

## Provisional decisions (made during implementation; please review)

These follow from the agreed changes, or were needed to write any code at
all. None of them has been explicitly agreed yet, except where a row
says "as agreed".

| # | Decision | Example | Why |
|---|----------|---------|-----|
| P1 | Array brackets are postfix too (superseded by #49: `[T]` and `[T](N)`) | `var a:i32[4];` | Mixing postfix `^` with prefix `[4]` would make `[4]i32^` ambiguous; `[T](N)` puts the count after the brackets, so suffixes still read left to right |
| P2 | Type suffixes apply left to right, but a run of brackets reads in C order (superseded by #49: `[[i32](3)](2)` is `int32_t[2][3]`) | `i32^[4]` was `int32_t *[4]`, `i32[4]^` `int32_t (*)[4]`, `i32[2][3]` `int32_t[2][3]` | So that `var m:i32[2][3]` indexes as `m[1][2]`, exactly as in C |
| P3 | ~~Variable declarations start with `var`~~ | | Superseded by #15, and back, with `let`, since #27 |
| P4 | `()` means no parameters | `let f():i32` is `int32_t f(void)` | C's `()` (unspecified parameters) is obsolescent |
| P5 | No `: type` after a function means it returns nothing | `let f()` is `void f(void)` | Same as v0.1. Kelvin itself has no `void` (#20) |
| P6 | Qualifiers bind to what is on their left; a leading qualifier binds to the base | `u8 const^` and `const u8^` are both `const uint8_t *`; `u8^ const` is `uint8_t *const` | This is C's rule, written postfix |
| P7 | Several names per declaration | `var a:i32 = 1, b:u8^;` | Each name has its own full type, since C's `int a, *b` split is gone |
| P8 | Struct and union members end with `;` | `struct p { x: i32; y: i32; };` | Kept from C, as is the `;` after `}`; since #35 a new line or the `}` ends them too, as in `struct p { x: i32; y: i32 }` |
| P9 | Storage class goes in front | `static let f():i32`, `static var n:i32`, `extern var optind:i32` | Kept from C |
| P10 | Anonymous enums are allowed | `enum { LIMIT = 3 };` | The common C idiom for constants |
| P11 | Kelvin reserves the sized type names, `String`, `any`, `nullptr`, `cstr`, `let` and `var` (`as` is reserved by #14) | | C code that uses them as identifiers cannot be named from Kelvin yet. `var` was unreserved by #15 and, with `let`, reserved again by #27. `String` stays reserved while shelved (#22) |
| P12 | Literals are passed through verbatim (minus suffixes, #13) | `0x1f`, `017`, `0b101`, `'\n'`, `"a" "b"` | So C interprets them exactly as it always has. Octal `017` and C23's `0b` stay |
| P13 | `u8` and C's `char` mix freely | `let s:u8^ := "hi";`, `let printf(fmt:const u8^, ...):i32;`, `let main(argc:i32, argv:u8^^):i32` | Follows from #7. String literals and libc use `char`, while `u8` is `unsigned char`. They are ABI-identical, so kelvinc silences C's pointer-sign and library-redeclaration warnings, and emits `main`'s `argv` as `char **`, which C requires |
| P14 | `true` and `false` are built in alongside `bool` | `var done:bool = false;` | `<stdbool.h>` provides all three together, and a `bool` without them would be half a feature. They are reserved words, and are `bool`s (P23) |
| P15 | Any identifier after `:` or `as` is a type name | `let f:FILE^ := stdout;`, `n as size_t` | Needed for #12: headers define typedef names that Kelvin cannot know without reading them. After `:` or `as` a type is certain, so this is unambiguous |
| P21 | How `print` formats values | `println(10.0, " ", 0.1:f32, " ", 1e300)` prints `10.0 0.1 1e+300` | Integers print in decimal, including `i128`/`u128`. Floats print in the shortest text that reads back the same, always with a `.` or an exponent. As agreed on 2026-10-06, they follow Swift's rule: plain decimal from 0.0001 up to 2 to the power of the type's mantissa bits (2^53 for `f64`, 2^24 for `f32`, `LDBL_MANT_DIG` bits for C's `long double`), where every integer is exact, and C's exponent form otherwise: `10.0`, `0.0001`, `9007199254740992.0`, but `1e+16`, `9.5e+15` and `1e-05`. Both forms use `.`, whatever the C locale's decimal point (agreed the same day). Every NaN prints `nan`, whatever its sign bit. `bool` prints `true`/`false`. `u8^`, `i8^` and string literals print as strings, with `(null)` for a null pointer. Other pointers print as addresses, and C's `char` as a character. Dispatch is by C type via `_Generic`; comparisons, `&&`, `||` and `!` are `bool`s since #23, so `x == y` prints `true` |
| P22 | Runtime layout and linking | `make` builds `libkelvin.a` plus `libkelvin.dylib` (macOS) or `libkelvin.so` (Linux); all in `modules/` beside the header since #46, and `make install` copies them to `$PREFIX/lib/kelvin/modules` | kelvinc links `libkelvin.a` statically, so programs need no runtime library at run time. It finds the runtime in Kelvin's `modules/` (P58). The shared libraries are for use from C and other toolchains. Zero-argument `print()`/`println()` rely on `__VA_OPT__`, which gcc and clang accept in C11 mode |
| P23 | `true` and `false` are `bool`s in the generated C | `println(true)` prints `true` | C's `true` is the `int` `1`. kelvinc emits `(bool)true`, so the prelude sees a `bool`. Arithmetic is unchanged (`true + 1` is 2) |
| P24 | A decimal literal above `INT64_MAX` gets C's `U` in the generated C | `18446744073709551615:u64` | Without suffixes (#13), C has no signed type for it and warns, although it already treats it as unsigned. kelvinc writes the `U` |
| P25 | ~~`String` holds up to 255 bytes inline, plus a NUL~~ | | Shelved by #22 |
| P26 | Method dispatch | `p.area()` becomes `({ __auto_type t = p; _Generic((t), ..., struct point: point__area, ...)(t); })` | kelvinc has no type checker, so C11 `_Generic` picks the method, and the receiver is evaluated once into a temporary (P31). The rules that follow from this: (1) as in C, a method must be declared (defined or prototyped as `let point.area():f64;`) before a call, for every receiver type; a method may call itself; (2) `x.name(...)` is a method call when `name` is a method somewhere in the file, and a call through a field otherwise; (3) enums cannot have methods, because C cannot tell an enum from its integer type; (4) `toString` and `fmt` cannot be defined while shelved (#22); (5) C typedef names (`size_t`) cannot be receivers; (6) `self` is passed by value; (7) `point.area` is the C function `point__area`, and two methods whose C names would collide (`a_.b`, `a._b`) are an error; (8) method calls cannot appear in global initializers |
| P27 | The text of built-in types, now `.cstr` (#22) | `0.1.cstr` is `0.10000000000000001`, `(0.1:f32).cstr` is `0.100000001` | Lossless, as agreed for `f64` (`%.17g`): `f32` uses `%.9g` and `long double` `%.21Lg`, and a NaN is `nan`. Complex numbers are `re+imi` (`1+2i`). Integers are decimal (including 128-bit) with no `+`, `bool` is `true`/`false`, and other pointers are hex addresses (`0x0` for null) |
| P28 | The derived text of a struct, now `.cstr` (#22) | `{from: {x: 3, y: 4}, to: {x: 6, y: 8}, tag: edge}`, `[{x: 0, y: 0}, ...]` | Fields are written `name: value`, nested structs recurse, and arrays print as `[a, b]` (a flexible array member as `[...]`). Text is unquoted, and pointers print as addresses (`u8^`/`i8^` as text). Fields of C types print through C's type (scalars) or as `{...}`. A union prints as `<union name>`, since its active member is unknown. Derived functions are `static inline`, so two files that share a struct still link |
| P29 | ~~`fmt()`~~ (shelved by #22; this was its design) | `n.fmt("%5d")`, `255.fmt("%#x")`, `42.fmt("%.2f")` is `42.00`, `(-1:i32).fmt("%x")` is `ffffffff` | One conversion (`diouxXcfFeEgGaAsp`) with flags, width and precision (each at most 4096), plus any text and `%%`. No length modifiers (#13: no size hints), since the value's own type decides. The value is converted to the conversion's kind (a float to an integer only within range), and an unsigned conversion of a negative value shows its bits in the value's own width. Integers, including 128-bit ones, are formatted by Kelvin with every flag defined; flags C leaves undefined for a conversion (`%05c`, `%#d`) are ignored. The format is never passed to C's printf. Anything else gives `<invalid format>` |
| P30 | A number ends before `.name` | `2.cstr`, `1.5.hex`, `0xff.bin`, `(7:i64).inc()` | So properties and methods apply to literals. `1.e5` and hex floats such as `0x1.f4p+9` are still numbers. `1.f` or `1.L` (a C suffix spelled as a field) is an error |
| P31 | Method calls use two GNU C extensions in the generated C, as does a property whose receiver holds a method call or property | `({ __auto_type _kv_p_self = p; ...; })` | A statement expression and `__auto_type` evaluate the receiver once and keep chained calls (`x.a().b().c()`) linear in size; without them the receiver had to be printed twice per call, doubling the C at each link of a chain. gcc and clang accept both in C11 mode. The ABI is unaffected |
| P32 | What counts as a reference for `:=` | `var p:i32^` (a reference), `var a:[i32^](2)` (a value), `var t:pthread_t` (unknown) | A pointer type is a reference. Built-in types, structs, unions, enums and arrays (even of pointers) are values, except that an array parameter is a pointer, as C adjusts it (`var argv:u8^[]`, so `argv := argv + 1`). A C typedef name is unknown, so both `=` and `:=` are accepted. Initializer lists and function arguments are not assignments |
| P33 | Two readings of #20 | `var q:i32^;` is `int32_t *q = 0;`; discarding is `x;` | (1) The user's example `var ptr:any^;` is applied to every reference: a pointer declared without a value is `nullptr`, local or global, except an `extern` declaration. (2) The discard idiom `x as void` went with `void`, and the user did not pick a replacement, so a value is discarded by writing it as a statement (C may warn about an unused value). Also, comparisons were C `int`s, so `println(p == nullptr)` printed `1`; since #23 it prints `true` |
| P34 | Property details | `(-5:i32).hex` is `-0x5`; `x.hex` emits `_Generic((x), ...)(x, _kv_x_text)`, with `uint8_t _kv_x_text[36];` at the top of the enclosing block | Integers are sign and magnitude (not two's complement), with lowercase digits and no padding. A NaN is `nan`, unsigned. The buffer is declared at the top of the enclosing block and fits the text of any type (41, 36, 47 and 132 bytes for `.dec`, `.hex`, `.oct` and `.bin`), so the text lives until that block ends, also when made in a brace-less `if`/`for` body or among a method call's arguments: storing `let t:u8^ := x.hex` is fine inside the block, but returning it is not (as with any C local), and kelvinc reports it in a `return` or a one-expression body (#35). An enum's sign follows its C type, and a C bit-field must be converted first (gcc's `_Generic` does not match it). `.dec`/`.hex`/`.oct`/`.bin` stay properties on receivers kelvinc cannot see (`(a + b).hex`), because such fields are rare; since #22 it also sees the results of Kelvin functions and methods (P35), so `get().hex` reads a field `hex` of the struct `get()` returns. A Kelvin struct's own field of that name still wins, and a C struct's too |
| P35 | `.cstr` details | `s.cstr` is `s` itself for a `cstr`; `p.cstr` is `_kv_point_cstr(p, _kv_p_text)` with `uint8_t _kv_p_text[_kv_point_cstr_size]` | A string (`u8^`, `i8^`, a literal) is its own text, not a copy (`(null)` for null), and stays `const` if it was; a pointer to `volatile` bytes is an address. One value's buffer is 64 bytes. A struct's derived function comes with a size constant, `_kv_point_cstr_size`, which C computes from the member types, so the buffer is exact; both are emitted only for structs whose `.cstr` is used, directly or as a member. Inside a struct, a string member shows at most 60 bytes and a longer one is cut with `...`; a pointer to a C typedef (`xmlChar^`, `uint8_t^`) is text or an address as C's type says; a member of a C typedef type shows numbers, bool, complex numbers, byte strings and `void *` as `.cstr` would, a char array as the text in it (never past its end), and anything else as `{...}` (C structs, other arrays, other pointer typedefs). A flexible array member behind a C typedef leaves the struct without `.cstr` (C's `sizeof` fails). kelvinc sees the type of names, `v as T`, compound literals and the results of Kelvin functions, and of methods (the method of the receiver's type where kelvinc sees it, otherwise when every method of that name returns the same type), and of `p^`, `a[i]` and fields of all of these, and of a `?:` between two values of one such type (#34). Anything else, such as `(q, p).cstr`, gets one value's buffer, and if C finds a Kelvin struct there, it is a C error naming `kv_cstr_unseen_struct` (assign it to a variable first), never an overflow. C struct and union values have no `.cstr` (inside a Kelvin struct they show as `{...}`). `.cstr` of an array kelvinc can see is an error (C arrays are not values). A Kelvin struct cannot have a field named `cstr` (a keyword); a C struct's field `cstr` wins, also as a designator. Derived functions are marked `__attribute__((unused))` |
| P36 | How the shelving reads (`String` is a type since #55; `toString` and `fmt` stay reserved) | `x.toString()`, `let point.fmt():cstr {...}` and `s:String` are errors that point at `.cstr`; `cstr const` is `uint8_t *const`; `cstr(v)` is an error | `String` stays a reserved word, and `toString` and `fmt` stay reserved as method names, so a later true string type can take them back without breaking code. Plain functions, variables and parameters named `toString` or `fmt` are fine (`let printf(fmt:const u8^, ...)`). A call through a field of that name still works where the field is visible, or where kelvinc cannot see the receiver (a C struct). `cstr` behaves as `u8^` written out: qualifiers after it apply to the pointer, as with a C typedef, and `:=` assigns it (#19). It is not a converter (P18): write `v as cstr` |
| P37 | Details of #23 | `if (n > 0) { ... }` still works; `for (i = 0; i < n; i += 1) x += i;` keeps a single-statement body; `var x:i32 = a < b;` is 1 | Parentheses around a condition are grouping, so a `(...)` before the body's `{` is never a compound literal there; in a condition, `(T){...}` and `sizeof (T){...}` are compound literals only when the expression goes on after the `}` (`(struct point){1, 2}.x == n`), so `if n == sizeof(i32) {} {` has an empty body. C's `if (c) x = 1;` and `else x = 1;` are errors that ask for a block, and `do`'s body is a block too, like `while`'s. `for` and `switch` keep C's syntax, including a statement body for `for`, until decided. A `bool` converts to numbers as in C. A condition kelvinc cannot see is wrapped as `_Generic((c), bool: kv_bool, default: kv_condition_is_not_bool)(c)`; one it sees is printed as written. In a value position a comparison or logical operator is `((bool)(...))`, and `?:` between two `bool`s is a `bool` (C would promote it to `int`); a discarded `a && f();` statement keeps C's form, which clang does not call unused. Since a `?:` or `&&` needs `bool` operands, statements like `flag ~ f() || g();` need `bool(...)` |
| P38 | Details of #26 | `x = 1, y = 2;`, `for (...; ...; i += 1, p := p.next)`, `n := n^.next` | A comma list of assignments is allowed at the top of any expression statement, not just in a `for` clause, and runs left to right. (Before #27 each item could declare or assign on its own; since #27 a list either declares, after `let` or `var`, or assigns.) `p.next` is `(p + 1)` and `p.prev` is `(p - 1)` for a pointer whose type kelvinc sees, including results of Kelvin functions; `.next` of an array is an error that suggests `&a[1]`, and `any^` has no `.next`. On anything else `.next` is a field (a struct, a C type kelvinc cannot see). `p += 1` stays. The comma operator stays for expressions that do not assign. A statement such as `a || f();` is still allowed, and gcc `-Wall` calls its value unused |
| P39 | Details of #27 | `let p:i32^ := &x;` is `int32_t *const p`; `let a:[i32](2) = [1, 2];` is `const int32_t a[2]`; `let f(n:i32)` is `void f(const int32_t n)` where defined | A let names a value that cannot change through it: a let struct's fields and a let array's elements cannot be assigned, while a let pointer's target can. kelvinc reports assignments to lets it can see (names, their fields, elements of let arrays), and the C compiler enforces the rest through `const`. A let needs a value except in an `extern` declaration. Let parameters are `const` only in a function's definition (C ignores top-level `const` in prototypes), and an array parameter becomes the `const` pointer C makes of it; a parameter of a C typedef kelvinc cannot see gets no `const`, since the typedef may be an array (`jmp_buf`), and kelvinc alone checks it. Taking `&` of a let gives a `const` pointer, so storing it in a plain pointer is a C warning (discarded qualifiers). `x:i32 = 0;` without `let` or `var`, when the type starts with a type word, is an error with a hint; `again: n = 0;` is a label, as in C. C-style declarations get `var name:type` as their hint |
| P40 | Details of #28 | `for i in 0..<n { }` is `for (int64_t _kv_i_count = 0, _kv_i_end = n; _kv_i_count < _kv_i_end; _kv_i_count++) { const int64_t i = _kv_i_count; ... }` | The bounds are evaluated once, before the loop. A closed range steps with a flag, so `for b:u8 in 250...255` ends instead of wrapping, and `continue` works in both. A bound is parsed down to the shifts (`0..<n - 1` is `0..<(n - 1)`). The loop variable's type is written, or is the upper bound's type if kelvinc sees it, else the lower one's, else `i64`, without `const` or `volatile` (the counter must change); both bounds and a written type must be integers. `for _ in ...` declares no variable, since C warns about an unused one. `in` is a keyword only after `for name`, so C names called `in` still work |
| P41 | Details of #29 | `var p:point;` is `struct point p;`; `sizeof(point)`; `var point:point;` | kelvinc resolves a bare tag name to `struct point` (or `union`/`enum`) wherever a type is read (after `:`, `as`, in compound literals), and writes the long form in the C: no C typedef is emitted, so a variable or function of the same name is fine. A tag declared so far counts, so a struct's members may name it (`next: node^`), as may a C struct that Kelvin declares (`struct timespec;`); a Kelvin tag hides a C typedef of the same name from a header. Where an expression could stand too, in `sizeof(name)` and `(name)...`: a Kelvin variable of that name wins (`sizeof(point)` after `var point:point` is the variable's size), from its own declarator on, as in C (`let p:node^ := malloc(sizeof(p^))`); a Kelvin function of that name wins too, except in `sizeof`, where a function's size is never meant (`node(v)` as a constructor and `sizeof(node)`); and a struct only declared in Kelvin (`struct timezone;`) is left to C there, because headers give such names to functions and variables too (`stat`, `timezone`), so `sizeof(struct timezone)` names the struct. C habits get the usual hints: `p:point = ...` (no `let`/`var`), `point^ p;`, `sizeof point` |
| P42 | Details of #30 | `for c in s { }` is `for (const uint8_t *_kv_c_ptr = s; _kv_c_ptr != 0 && *_kv_c_ptr != 0; _kv_c_ptr++) { const uint8_t c = *_kv_c_ptr; ... }` | `s` is evaluated once into a hidden pointer that only reads, so `s` itself never moves and a let array works. The loop variable is a let copy of the element without its qualifiers, or for a list a let copy of the node pointer, taken (with the next pointer) before the body runs, so the body may change or free the node. The terminator is a zero element: `0`, `'\0'`, `nullptr`, `0.0` or `false`. An array of structs has none, so all of its elements are walked. A pointer whose type kelvinc cannot see (a C function's result, a C typedef) is walked like a pointer, with C's `__auto_type` and `__typeof__`. A list needs a Kelvin struct with a pointer field named `next`; a number, an `any^`, an array of arrays, a flexible array member, or a C struct kelvinc cannot see the fields of is an error. `for x:T in s` reads the elements as what they are and converts each to `T` for `x` only; for a list, `T` must be the node's pointer. An array is reached through a pointer to it, taken once, so a row of a variable length array is evaluated once, although `sizeof` would evaluate it again. An array in a value that a call or `?:` returns (`make().xs`) is an error, since C discards the value before the loop runs; so is a row of an array kelvinc cannot see there. A let array parameter, which C passes as a pointer, has its declared length, evaluated again at the loop, so the length must be made of numbers, lets and C's constants, with no call, no var and no name that a local hides; that the argument is that long is the caller's promise, as in C. A var array parameter may have moved (P32), so it is walked as a pointer. `main`'s `argv`, which C types `char **`, is converted for the hidden pointer. The hidden lines map to the `for`'s line. In the head, a compound literal followed by `..<` or `...`, and an array's or a pointer's before the body (`for x in ([i32](3))[1, 2, 3] {`), are compound literals. `0..n` and `0..=n` get the range hint. kelvinc now also sees `&x`'s type, `T^` |
| P43 | Details of #31 | `before:(i64, i64):bool` is `bool (*before)(int64_t, int64_t)`; `let pick():(i64):i64` is `int64_t (*pick(void))(int64_t)` | `(T)` and `()` have no result, and `...` ends a variadic one. The parameters are types without names; an array parameter is printed in C as the pointer C makes of it. The result takes every suffix after it (`(i64):i64^` returns a pointer); a pointer to a function type or an array of functions has no spelling yet, and says so. In the middle of `?:`, a `:` after a function type with no result is the `?:`'s unless a type word follows, as for annotations (`c ? f as (i64) : nullptr`). A function type is a reference (P32): assigned with `:=`, `nullptr` until assigned, compared with `nullptr`, and a let one is a const pointer. A Kelvin function's name, and an anonymous function, designate a function, which is its function value: `&f` is `f`, and `f.size` and `sizeof(f)` are `sizeof(&f)`, a pointer's size. `?:` between functions is a function; a call through a function value is a call whose result kelvinc sees. Function types are read after a declaration's `:` and after `as`, not as an annotation `v:(T):R` (which would clash with `c ? a : (b)`) and not inside `(...)` in an expression. Where kelvinc sees a function, `.cstr`, `.next`, `.prev` and `print`/`println` of it are errors; `&fp` of a variable of a function type is an ordinary data pointer. In a struct's derived text, a function member is its address. A C function with `char` parameters does not match a Kelvin function type with `u8` ones, since `char` and `unsigned char` make incompatible function types (P13 covers pointers only), so it is wrapped: `{ strcmp($0, $1) }`; for the same reason `main`, whose `argv` C types `char **`, is not a `(i32, u8^^):i32` value. C's `T (*f)(...)` gets a hint with the Kelvin spelling, in a body, at the top level, as a member and as a parameter |
| P44 | Details of #32 | `sort(xs, n) { $0 < $1 }` passes `_kv_main_fn` (when written in `main`), declared before the function around it and defined after it as `__attribute__((unused)) static inline bool _kv_main_fn(__attribute__((unused)) const int64_t _kv_arg0, __attribute__((unused)) const int64_t _kv_arg1) { return ((bool)(_kv_arg0 < _kv_arg1)); }` | Each anonymous function is a static inline function named after the top-level declaration it is written in, `_kv_main_fn`, then `_kv_main_fn1` and so on (#33, #38), its prototype too, marked unused (one used only in `sizeof` is never emitted), declared before the top-level declaration around it (a function, a method, one global of a `let`/`var` list, a struct, union or enum, after a `struct s;` its prototypes may name) and defined after it, so each may use the other, and a global's function may use that global and the ones before it. Its parameters are lets, `$k` ones marked unused, and its array parameters are pointers in C. Where a `{` may start one (an argument, an initializer, a value assigned or returned), it is parsed as an expression, so one that writes its parameters may be called or compared there, and one that writes them may stand anywhere a value may. Their types come from the parameter of a Kelvin function, method or function value it is passed to (for a method whose receiver kelvinc cannot see, the only method of that name, a prototype and its definition counting once), a declared variable's type, a struct member's or array element's type in an initializer list (in order and through designators of one member; a string fills an array member and a value of the struct's type fills a struct member, while after brace elision or a longer designator there is none), the type of an assignment's target (also through a cast or a call), or the result type of the function that returns it. An array length in such a type that names a local or a parameter, also inside `sizeof`, a conversion or a compound literal (recorded where the type is written), means something else in the anonymous function: the parameter's outer array becomes a pointer, and such a length anywhere else that reaches C is an error asking for written parameters; lengths of numbers and globals are kept, and `for x in $0` checks them against the names C will see. Without a type in sight it writes its parameters, or has none (`atexit() { ... }`); in a declaration without a type, `{` is an initializer list unless it writes them (`{ () in ... }`). Where a list is taken for a value (a C function's argument, a struct parameter, an assignment, `println`), kelvinc asks for a compound literal. A written signature without `:R` takes the result from the context (checked as above), or has none; an inferred type drops the outer array lengths that name its parameters, and another such length is an error saying so. `$k` and `$[k]` are the innermost anonymous function's parameter `k`, also when they are written; `k` is decimal without leading zeros, messages spell it as written, and `$` is an error in the written parameters themselves. A body that is one expression statement is the result (#35 parses every body as statements); with a result it may not be an assignment or a call kelvinc sees has no value (P46), and without one it must have an effect: a call, an assignment, or a comma or `?:` of those (`{x: 1}`, a label before `1` as a body, is therefore still a list where C's argument is meant). Returning text in the function's own buffer (`.hex`, `.cstr` of anything but a string kelvinc sees), also through `as`, `?:`, the comma, `+`/`-` or `&x[i]`, and in a `return` statement, is an error. It encloses nothing: a local, a parameter (also a static local or `self`) of the function around it is an error, in its body and in its written types; globals, functions and C names are fine. A trailing `{ }` follows the `)` of a call or method call; at the top level of a statement it starts on the line of that `)` (on the next line, `{` starts a block, and `$0` there says so), while inside brackets lines do not matter; like every statement since #35, one ending with it needs no `;` at the end of a line or before a `}`. In the head of `if`, `while` or `for`, the `{` starts the body; inside parentheses (a converter's included), an initializer list, or `do ... while`, it is an argument. Passing one where kelvinc sees a parameter that is not a function, or beyond the last parameter of a function that is not variadic, is an error; where the parameter is a C typedef, the hint asks whether an argument is missing. It is recognized by `in` after the parameters and result, or by the shapes `(a:T)`, `(var a:T)` and `()` when nothing can go on with an expression after them, so `{ (n:i64) * 2, 3 }` is a list. Names starting with `_kv_` are kelvinc's own and `kv_` ones its runtime's (#38), so Kelvin cannot declare either: variables, parameters, members, functions, methods, enumerators, tags, loop variables and labels |
| P45 | Details of #34 | `var w:k.type = 4;` for `let k = 3` is `int64_t w = 4;`; `var e:errno.type;` is `__typeof__(errno) e;`; `var b:a.type;` for a variable length `a` is `__typeof__(a) b;`; `k.typename` is `"i64"`, `abs(-1).typename` is `_Generic((abs(-1)), ..., int: "i32", ...)` | `v` in `v.type` is a name or `$k`, then `.member`, `^` and `[i]` steps, and the last `.type` in such a chain is the type; `^`, `[n]` and qualifiers after it make a new type of it (`w.type^`), and a `const` before it is on an array's elements, as in C. Calls are not part of it. It is read wherever a type is read: after a declaration's `:`, `as` and an annotation's `:`, in `sizeof(...)`, compound literals (also in a `for` head, for an array or a pointer), function types, a written signature's result and `for x:T`. Where an expression could stand too, in `sizeof(x.type)` and `(x.type)`, it is a field when `x` has one, is a C struct, or has a type kelvinc cannot see; after a qualifier, `:` and `as`, and before a compound literal's `{`, it is always the type. The type is the one kelvinc sees (a copy), so a `let`'s own `const` is not part of it, while a `const` written in the type is. It is `__typeof__(v)` instead where kelvinc cannot see it, where it holds an expression C would evaluate again (a length that is not a number, an earlier `__typeof__`), and for a parameter whose declared type kelvinc cannot see (C adjusts an array, as `jmp_buf`, to a pointer); that keeps `v`'s own length and also a `let`'s `const`, and kelvinc keeps the type it saw for its own checks. A function designator's fallback is `__typeof__(&f)`, a function value; a C function kelvinc cannot see is C's function type, whose pointer is `f.type^`. A `for` counter of such a type is `__typeof__((void)0, (v))`, without qualifiers. A result type that names a parameter through `__typeof__` is an error (C writes the result before the parameters). `point.type` of a tag with a body, and `i64.type` of a built-in type, ask for the type itself; a C typedef name is left to C. Inside an anonymous function, `.type` of a local of the function around it is the usual error. A pointer to a function type or an array of functions made with `.type` is the P43 error. In an expression, `.type` is a field where there may be one and otherwise an error, also in parentheses. `.typename` is a string literal where kelvinc sees the type and it holds no `__typeof__` (Kelvin tags by their bare names, a function type under `^` or `[n]` in parentheses, C structs as `struct tm`, escaped for C); otherwise `kv_typename(v)`, a `_Generic` over C's built-in types (C's `long` by `__SIZEOF_LONG__`, `char` as `u8`) and the pointers to characters and `void`, with `"?"` for anything else: arrays decay, enums are their integer type, and bit-fields may differ between clang and gcc. A literal is C's (`42` is `i32`, as `42.size` is 4), `nullptr` is `any^`, and a `?:` between two values of one type is that type. `.typename` is a property also of a C struct and of what kelvinc cannot see, since C++ reserves the word; a Kelvin struct's field of that name wins. A variable used only for its `.type` or `.typename` is unused as far as C sees (`-Wunused-variable` under `-Wall`). The prelude does not include `<limits.h>`, whose names stay the user's |
| P46 | Details of #35 | `let t:i64 = price\n    * count` is one statement; `f(x)\n(p as i64^)^ = 1` is two; `let square(x:i64):i64 { x * x }` returns `x * x` | A statement, a declaration, a struct member, a struct, union or enum, and a prototype (`let f(a:i32):i32` with no body, also of a method) end with `;`, or with a new line, a `}` or the end of the file after them; otherwise `;` is required between them, except after a statement that ends with a block (`if c { a = 1 } b = 2`), whose `}` ends it, as in C. After the head of a function, a method, `if`, `while`, `for`, `else`, `do` or `switch`, a `{` on the next line is the body. Lines go on wherever the expression cannot end (after an operator, a `,` or an open bracket), and before an operator, `.`, `[`, `^`, `?`, `:` or `as`; a `-` or `&` at the start of a line is therefore a binary operator, while a `*` there touching what is then assigned (`*p = 1`) is C's `*p`, an error. At the top level of a statement, a `(` on a new line starts the next statement rather than calling what went before, and a `{` there starts a block: a trailing `{ }` starts on the line of the call's `)` (a block there that writes an anonymous function's parameters, or that follows a call lacking its function argument, is an error saying so), `(n)` or `sizeof(T)` before it is no compound literal (`(T)` before it is an error saying so), and `(x)` before a name on the next line is no C cast; inside brackets lines do not matter. `break`, `continue` and `goto L` end at the end of their line. So does `return` in a function with no result, where a statement after it in the same block is an error, as it could never run, unless it is `case`, `default`, a label or a block holding one, the `return` is the body of `for` or a label, or it is C's `return;`; in a function with a result, `return` at the end of a line takes the expression on the next line, as in Swift. `_Pragma("...")` is a statement also at the end of a line. A function, method or anonymous function with a result whose body is one expression statement returns it. An assignment there is an error, and so is a call kelvinc sees has no value (`print`, `println`, a Kelvin function, method or function value with no result, `_Pragma`, `asm`); `main` keeps C's rule that its end returns 0, so its one expression is a statement (`let main():i32 { 42 }` is an error asking for `return`). A body that ends, on any path (both branches of `if`/`else`, a block, a label, a switch's last statement, or one with no effect before a case), in an expression with no effect, or outside `main` in a call kelvinc sees has a result, is an error asking for `return`, and text in the function's own buffer (`x.hex`) is one in a `return` too. Bodies are parsed as statements, so an anonymous function's body is one expression by the same rule. A statement that starts with `n:T` is an annotation, not a label, when an operator, `as` or `?` follows the type, or when it is the expression a body returns (`let widen(n:i32):i64 { n:i64 }`); with a C typedef `T`, only in that expression and when kelvinc sees `n`; C habits keep their hints at the end of a line and before a `}`: `count:i32`, `size_t n` and `FILE *fp`. `;` stays valid everywhere |
| P47 | Details of #36 | `i32("755", 8)` is `((int32_t)kv_text_int(("755"), (8), INT32_MIN, INT32_MAX))`; `i64(f())` of a C function is `({ __auto_type _kv_self0 = ((void)0, (f())); KV_TEXT(int64_t, _kv_self0, kv_text_int(KV_TEXT_PTR(_kv_self0), 10, INT64_MIN, INT64_MAX)); })` | The runtime's `kv_text_int`, `kv_text_uint`, `kv_text_i128`, `kv_text_u128`, `kv_text_f64` and `kv_text_f32` read the text after leading spaces and one sign (a second sign or a space there is no number), skipping `0o` and `0b` in base 8 and 2 as `strtoull` skips `0x` in base 16; i128 and u128 are read digit by digit the same way. No number, a NULL text or a base outside 2 to 36 at run time (the base is taken as a 64-bit value) is 0. For integers, a clamped value sets `errno` to `ERANGE` and leaves it alone otherwise; an unsigned type's lowest is 0, so `u8("-1")` is 0. Floats are `strtod`/`strtof` itself: infinities out of range, `ERANGE` also on underflow, and the C locale's decimal point. Text is a string literal, a pointer to or array of `u8` or `i8` that is not volatile, a text property (`.dec`, `.hex`, `.oct`, `.bin`, `.cstr`, `.typename`) or a `?:` of those (whose arms become `const void *`). A number kelvinc sees (a literal, `sizeof`, arithmetic, a prefix operator, a comparison) converts as before; anything else it cannot see as text or a number, including a pointer to a C typedef such as `xmlChar^`, goes through `KV_TEXT`, whose `_Generic` reads `char *`, `signed char *` and `unsigned char *` (const or not) and converts anything else. Inside a function, the value is first put in a temporary, so that it is evaluated and written once and nesting stays linear; at file scope `KV_TEXT` is used directly and stays a constant expression for numbers, so `let big = u64(UINT32_MAX)` still initializes a global. With a base, the value must be text: after a number kelvinc sees it is an error, and where only `_Generic` sees it, a C type error names `kv_base_needs_text`. A written base outside 2 to 36, in any radix or negated, or a float, is an error. `v.T` is `T(v)` for every converter type, numbers included (`300.u8` is 44), except that a field of that name wins: a Kelvin struct's, a C struct's, and, as for `.size`, one of whatever kelvinc cannot see is not a struct (`o.via.i64`); a Kelvin struct or union without one is an error, and so is `.i64(...)` where it is not a field. `bool` reads no text: `bool(p)` of a pointer is C's test for `nullptr`, and of a string literal or a text property, which is never `nullptr`, an error. A number read from text is no text in the function's buffer, so `{ i64(x.hex, 16) }` may be returned |
| P48 | Details of #37 | `p.addr` is `((uintptr_t)(p))`; `p.hex` is `kv_hex_addr((uintptr_t)(p), _kv_p_text)`; `getenv("X").hex` is `_Generic((...), KV_PROPERTY_hex default: KV_HEX_DEFAULT((...)))(..., _kv_text0)` | Pointers are what kelvinc sees as `T^` (also `any^` and `cstr`) or a function type, a Kelvin function's or an anonymous function's name, a string literal, `nullptr`, `&x`, a text property (`.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.typename`, all `u8^`), a pointer plus or minus a number, and a `?:` or comma of pointers. `.hex` writes into the same 36-byte buffer as an integer's `.hex`, so returning it is the usual error, while `.addr` is a number that may be returned. Where kelvinc cannot see the receiver, `.addr` is a field, as `.size` is (#21: a field wins when unsure; C structs often have an `addr`), so a pointer only C sees writes `x as uintptr_t`; `.hex` stays a property: `KV_HEX_DEFAULT` picks `kv_hex_ptr` for any pointer by GCC's and clang's `__builtin_classify_type`, and `kv_no_such_property` for anything else, so `.hex` of a C struct is still a C error naming it. `__builtin_classify_type` sees an array as a pointer, so an array only C sees (a C struct's `char` array field) gives its first element's address, as `.typename` and `.cstr` of one do. A function pointer only `_Generic` sees is passed as a `const volatile void *`, which `-pedantic` warns about; a value kelvinc sees is converted to `uintptr_t` first. `.addr` is an unsigned integer for other properties and converters (`p.addr.hex`, `p.addr.u64`) and needs a written type in a declaration (`let a:uintptr_t = p.addr`), as `.size` does; methods on `u64` do not reach it where `uintptr_t` is `unsigned long`, as with `.size`. A Kelvin struct without an `addr` field, a number or a bool is an error for `.addr`; `.hex` of a struct or a bool keeps its error |
| P49 | Details of #38 | `n.hex` writes into `_kv_n_text`, `for i in 0..<n` counts with `_kv_i_count` and `_kv_i_end` (and a closed range `0...n` steps with `_kv_i_go`), and `sort(xs, n) { $0 < $1 }` in `main` passes `_kv_main_fn` | A hidden name is `_kv_`, its source, and its kind. The source is a variable's or a parameter's name (`$0` is `arg0`), a member chain joined with `_` (`p^.x` is `p_x`), what is indexed or stepped, a loop's variable, or for an anonymous function, the top-level declaration it is written in (a method `point.area` is `point_area`, a global or a struct, union or enum its name). The kinds are `text` (a property's buffer), `self` (a temporary for a method's receiver, a condition, or a converter's value), `count`, `end` and `go` (a range), `ptr`, `end` and `array` (`for x in`), `fn` (an anonymous function), `template`, `build` and `value` (a template literal, #39), and `arg0`, `arg1`, ... (an anonymous function's `$k` parameters, by their number). Each stem counts on its own within a C function (and anonymous functions in the file), so a repeat is numbered 1, 2, ... and nothing is ever shadowed; with no source (`(a + b).hex`, `for _ in`), the kind is numbered from 0. Only names a construct uses are taken. A struct's derived text is `_kv_point_cstr(self, _kv_buf)`, writing with `_kv_p`, with its size `_kv_point_cstr_size`, and its array loops count with `_kv_i0`, `_kv_i1` by depth. Methods keep the names Kelvin gave them (`point__area`, P26), since they are the program's, and the runtime's functions and macros keep `kv_` and `KV_`. Kelvin cannot declare names starting with `_kv_`, `kv_` or `KV_` |
| P50 | Details of #39 | `` `n = ${n}, ${name}` `` in a block is `({ KV_TEMPLATE_BUILD(_kv_build0, _kv_template0); KV_TEMPLATE_PART(_kv_build0, "n = "); __auto_type _kv_value0 = ((void)0, (n)); KV_TEMPLATE_VALUE(_kv_build0, 20, _kv_value0); KV_TEMPLATE_PART(_kv_build0, ", "); __auto_type _kv_value1 = ((void)0, (name)); KV_TEMPLATE_VALUE(_kv_build0, KV_TEMPLATE_STR, _kv_value1); KV_TEMPLATE_TAKE(_kv_template0, _kv_build0); })`, with `char _kv_template0[sizeof "n = " ", " + 20 + KV_TEMPLATE_STR];` at the top of the block (P56) | The lexer reads a template's text as C string literals, between which the tokens of each `${...}` come; a `}` closes the `${` when the braces opened inside it are closed, so a value may hold blocks, anonymous functions and other templates. A template without `${...}` is a string literal token (described as a template literal in messages), which also joins adjacent string literals. Escapes are C's, plus `` \` ``, `\$`, `\{`, `\}` and a backslash before a new line, which joins the lines; a new line, CRLF included, is `\n`, a lone CR `\r`, and `?` is written `\?`, so no C trigraph forms. A token after a multi-line template counts its line from the template's last line (#35). Each evaluation builds its text in a buffer of its own, appending the literal parts and each value, evaluated once into a temporary in order, through `KV_TEMPLATE_VALUE` (a `_Generic` over the types `print` takes, sharing `print`'s text functions), and then copies it into the template's storage, so a value may read the earlier text. The storage, at the top of the enclosing block, has no heap and no initializer, so a `switch` or `goto` may jump past it, and lives until the block ends (#44, P56). The text is a `char *`, as a string literal is, so `?:` may choose between templates and literals; for converters and properties it is a `u8^` (`i64(`${n}`)`, `` `...`.size `` is a pointer's size). A Kelvin struct or union is shown by its derived `.cstr`; a function value or name is an error; a C struct is a C type error. Its text is the block's, so returning it, implicitly, with `return` or through `.cstr`, is an error, as is assigning it to a variable of an outer block or a global (but not to the function's own parameters, which end with its body); a global or `static` cannot be initialized with one that has `${...}`. In an anonymous function it uses that function's block, and it may not use the enclosing function's locals |
| P51 | Details of #40 | `#import "lib/shapes.k"` is followed by that file's declarations; `#import <complex.k>` reads `complex.k` from `./modules` or Kelvin's `modules/` (#46) | The lexer takes `#import` of a name ending in `.k`, without `as C`, as a Kelvin file; `as C` or other text after one is an error. Before parsing, kelvinc puts each such file's tokens after its import, and the imports in them in turn, so that its declarations are compiled as if written there: they are the program's, declared before what follows, as in C. A file is brought in once per program, by its device and inode, the main file included, so another import of it, also through another file, another path, a symlink or a hard link, adds nothing; a CRLF may end its line. The import stays, and the end of each imported file is marked, so a declaration ends where a file begins or ends, whatever the numbers of their lines; an unfinished declaration at the end of an imported file is an error there; and `#import` inside a function, a struct or a block is an error at the import, of a C header too. `"x.k"` is relative to the importing file (an absolute path as it is), `<x.k>` is `./modules/x.k`, else `x.k` in Kelvin's `modules/` (P58); a directory is no Kelvin file. A file it cannot find is an error at the import. A `"header.h"` that an imported file imports as C is the one next to that file, as C's `#include` would find it, written with the full path of that file's directory (a symlinked header keeping its own directory; a path that holds a `"` is left as written). kelvinc's messages and the C compiler's (through `#line`) name the imported file and its lines. Imported functions are named by their parameter types in C (P52), except those declared but never defined (C's own); structs and globals keep their names |
| P52 | Details of #41 | `sin(z)` of a `complex64` is `sin__complex64(z)` and `sin(0.5)` is C's `sin(0.5)`; with `twice(n:i64)` and `twice(x:f64)`, `twice(atan2(y, x))` is `({ __auto_type _kv_self0 = ((void)0, (atan2(y, x))); __builtin_choose_expr(KV_NUMBER(_kv_self0) == KV_N_I64, twice__i64, __builtin_choose_expr(KV_NUMBER(_kv_self0) == KV_N_F64, twice__f64, kv_no_such_overload))(_kv_self0); })` | Overloads differ in their parameter types as Kelvin writes them, without a parameter's own qualifiers, an array parameter being a pointer; one with the same types is the same function, a prototype or a definition, with the same result. `main` has one form, and methods dispatch by receiver (P26). An argument has the type of its value, where C's `const` of a `let` is kept (`&v` and an array that is a `let` point to `const`); a literal has its own, also negated (#24: `4` is an `i64`, `-0.5` an `f64`), and a character is a `u8`; a comparison, `&&`, `\|\|`, `!` and `true` are `bool`; an enumerator is its enum; `sizeof` is a `size_t`; and `+`, `-`, `*` and the other arithmetic on numbers kelvinc sees has the type C's promotions and conversions give, a literal there having C's type (an `int` where it fits, so `small * 4` is an `i32`). It fits a parameter exactly (the same type, a function type's array parameters being pointers), by conversion (a number to any number, also to a C typedef, which kelvinc cannot tell from one; a pointer to the same one whose target gains qualifiers, never loses them, the levels below it the same, or to or from `any^`; `nullptr` to a pointer or a function; text to `u8^`, `i8^` or `any^`; an overloaded function's name to a function type one of its overloads has, exactly), or not at all. The overload that all arguments fit exactly is chosen, and two such are a tie. Otherwise the one that fits at least as well as every other on each argument kelvinc sees, and better on one, where both have the same parameter type at each argument only C sees, is chosen; a tie is an error asking for a conversion (an `i32` fits `i64` and `f64` alike, Q14). With none, C's own function of the name is called. A program's one function of a name, also an imported one, is called as C calls it, except where it takes a struct and is given a number, which is for C's own function of the name (`sin(z.real)` inside `sin(z:complex64)`), or a value only C sees, which goes to C's function where the program calls it, and to the function itself otherwise. Where kelvinc cannot see an argument's type (a C function's result, a C struct's field, a macro), C chooses among the overloads left, over each such argument; inside a function the arguments go into temporaries first, a literal cast to its Kelvin type. Structs, pointers and C typedefs are matched by their C type, each in a `_Generic` of its own, so that two types that are the same in C (`size_t` and `uintptr_t`) cannot clash; numbers by `KV_NUMBER`, their Kelvin type, so that C's `long` and `long long` are both `i64` where they have 64 bits, and `char` is `u8`; and then an enum by its C type, which C cannot tell from its integer type. A number of another type goes to the one overload that takes a number there, which C converts it to, and a pointer to the one that takes a pointer, so `char *` and `void *` reach a `u8^` or `any^` parameter; where none does, to the one whose `...` covers that argument; else to C's own function of the name where the program calls it (then every such argument is checked, also where all the overloads left take one type there); and otherwise, as where several do, to `kv_no_such_overload`, a C type error that names it. So that C's function takes the numbers that only C sees whether or not the program calls it, a library declares it, as modules/complex.k declares `let tanh(x:f64):f64`; a function declared and never defined is C's, keeps its name, and is one of the overloads. One overload left with nothing else to choose is called, and C converts or reports. Such a call's result has a type kelvinc sees when all the overloads it may reach have that result and no number may go to C's own function. A function is named by its parameter types in C (`twice__i64`, `twice__const_u8p`: `^` is `p`, `[` is `a`, a space `_`, a function type `F` its parameters `E` its result, `...` is `__va`, and no parameters `__void`) when it has overloads, is imported, or shares its name with a C function the program calls; otherwise it keeps its name, and so do `main` and a function the program declares but never defines. Two functions or methods that would get the same C name are an error naming the other's place. A function's name as a value is the overload of the function type wanted: a typed `let` or `var`, the target of `:=`, a parameter, or a function's result, also of a body that is one expression; where no Kelvin overload has that type, it is C's own function of the name (`let g:(f64):f64 := sqrt` beside `sqrt(v:vec)`); an overloaded name elsewhere is an error. An anonymous function passed to an overloaded function takes its parameter types from the overloads where they all agree, and writes them otherwise. A call sees the overloads declared before it, as C does. `(f)(x)` keeps its parentheses, which call the function rather than a macro of its name. Limits remain: a C function-like macro such as `isnan` cannot take a value only C sees beside an overload of its name; gcc gives a C header's bit-field no type `_Generic` knows; and a Kelvin function of a C function's name that the program neither calls as C's nor declares keeps its name, which conflicts with the C header's, as it would in C |
| P53 | Details of #42 | `let +(a:complex64, b:complex64):complex64 { ... }` is `__attribute__((warn_unused_result)) struct complex64 _kv_add_op__complex64__complex64(const struct complex64 a, const struct complex64 b)`, and `a + b` calls it | `+ - * / % == != < <= > >=` take two values and `-` also one, none variadic; at least one is a Kelvin struct or union (also one declared without its body yet), and the operator has a result. Defining another (`<<`, `!`, `+=`) is an error. A definition is a top-level `let` with the operator's head, `let op(a:T, ...):R` (#45; before, a definition started on a new line, told by its head, and ended a value or a type before it). Operators overload by both operands as functions do (P52), and keep C's precedence. `a op b` with an operand that is a Kelvin struct, also one that a call C chooses gives, calls the operator chosen, and is an error showing how to define one where none fits, with a literal's type; numbers keep C's operators. Where the other operand's type only C sees, `_Generic` chooses as for functions, and what no operator takes goes to `kv_no_such_operator`, a C type error. In C an operator is `_kv_`, a word (`add`, `sub`, `mul`, `div`, `mod`, `eq`, `ne`, `lt`, `le`, `gt`, `ge`, and `neg` for `-a`), `_op` and its types, and its result must be used, so C warns about `m == a;` as a statement (gcc not where C chooses the operator). `x op= y` with an operator a struct defines is `x = x op y`, which evaluates `x` twice, so `x` may not hold a call |
| P54 | Details of #43 | `exp(z)` is `exp__complex64(z)`, `z * w` is `_kv_mul_op__complex64__complex64(z, w)`, and `exp(z.real) * (complex64){cos(z.imag), sin(z.imag)}` in `exp` is `_kv_mul_op__f64__complex64(exp(z.real), (struct complex64){cos(z.imag), sin(z.imag)})`, as `exp` of an `f64` is C's, which the file declares | `struct complex64 { real: f64; imag: f64 }`, and `complex32` with `f32` parts, named by the size of a part. `complex64(re, im)`, `complex64(re)` and `complex64(z)` of a `complex32` make one, as `complex32(...)` does the other way, and so does `polar(r, theta)` (`f64` gives `complex64`, `f32` gives `complex32`); `(complex64){re, im}` works, as for any struct. `+ - * /` take two complex numbers of one kind, or one and a real number of its parts' type, either way round (a whole number converts), plus `-z`, `==` and `!=`; division is Smith's algorithm, in Baudin and Smith's form where the ratio of the divisor's parts is subnormal, scaled where its finite parts pass 1e300; by 0 it is infinite and by an infinity 0, as C's is, and a numerator part near `DBL_MAX` overflows as C's does. Mixing `complex32` and `complex64` is an error: convert one. The functions are `conj`, `abs` (by `hypot`), `arg` (by `atan2`, from -π to π), `norm` (`abs(z)` squared), `exp`, `log`, `sqrt`, `pow` (a complex or real power of a complex or real number), `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh` and their inverses. The inverses take their principal values, with C99's branch cuts and its signs of zero on them; the circular functions are the hyperbolic ones at `iz`, as C99 defines them. `asin`, `acos` and `acosh` are Kahan's formulas, and beyond 1e300 the asymptotic `log 2z`, `acos` taking its real part from the angle; `atanh` uses `log1p`, and its limits where `z` is far or `y²` would underflow; `log` uses `log1p` where a part is near ±1 and scales a huge or tiny `z`; `tanh` is Kahan's algorithm; `sqrt` scales the sum that gives its larger part where `z` is huge or tiny, forms the other part from `z`, and gives C99's values for an infinite part, also beside a NaN; `exp`, `sinh` and `cosh` split `e^x` where it alone would overflow; `pow(0, w)` is 1 for `w` 0, 0 for a positive real part, infinite for a negative real `w`, and NaN for a NaN. The file declares C's functions of the names it overloads (`let tanh(x:f64):f64`, P52), so that `tanh(atof(s))` is C's `tanh`. So results are accurate near 0, ±1 and ±i, and no step of the elementary functions overflows or loses bits where the result does not, up to parts of `DBL_MAX`; they agree with macOS's libm `<complex.h>` to 1e-13 on the cases tested, which include subnormal, infinite and huge parts. C99's Annex G special values for other infinities and NaNs are not attempted; where Annex G gives `catanh(1 + 0i)` as `inf + 0i`, macOS's libm gives `inf + i pi/4`, and this file follows Annex G. `complex32` computes through `complex64`. A complex number's text is its derived `.cstr`, as `{real: 1, imag: 2}`, also in a template, and in `print` since #122 |
| P55 | kelvinc compiles with `-ffp-contract=off` | `a * b + c` is rounded twice | clang (Apple's on arm64 and others) fuses `a * b + c` into one `fma()` by default, while gcc in ISO C mode does not, so the same Kelvin program gave different floating-point results under the two, and in modules/complex.k `z * w` differed from `w * z` and `z * conj(z)` had an imaginary part. kelvinc now asks both for C's unfused arithmetic. `KELVIN_CFLAGS=-ffp-contract=on` brings clang's fusion back (`fast` only with `-O`). With `-O`, clang on macOS may also compute `sin` and `cos` of one value in one call, whose result can differ from theirs in the last bit |
| P56 | Details of #44 | `` `<${s}>` `` with a 399-byte `s` is 258 bytes, ending in `...>`; its storage is `char _kv_template0[sizeof "<" ">" + KV_TEMPLATE_STR];` | A template's storage is a `char` array at the top of the innermost block that holds it, declared with the text properties' buffers (P34, P35) and marked unused (a macro may drop the template, as `assert` does under `NDEBUG`), without an initializer or a cleanup attribute, so a `switch` or `goto` may jump past it and nothing moves to the function's top: text made in a switch's body lives until that body ends. A template with `${...}` in a type, as in an anonymous function's written parameters, is an error. Its size is a C constant: the literal parts with one NUL (`sizeof "a" "b"`), plus each value's longest text as `print` shows it, which kelvinc reckons from the type it sees: `i8` 4, `u8` 3, `i16` 6, `u16` 5, `i32` 11, `u32` 10, `i64` and `u64` 20, `i128` and an enum 40 (gcc gives an enum beyond 64 bits an `__int128` type), `u128` 39, `f32` 15, `f64` 24, `bool` 5, an address `sizeof(void *) * 2 + 2`, a struct's text its `_kv_X_cstr_size - 1`, `.dec`, `.hex`, `.oct` and `.bin` 40, 35, 46 and 131, `.size` and `.addr` 20, a string literal its length, a nested template its own storage's, the longer arm of a `?:` between texts (through a `union`, so that each arm is written once and a chain of `?:` stays as long as it is written), and arithmetic and `?:` as the widest kind of their operands, as C promotes them (any integer 20, `i128` and an enum 40, floats 24). For numbers, C checks the bound against the type it sees (`KV_TEMPLATE_BOUND` in a `_Static_assert`), so a wrong one is a compile error, never an overflow; a text's room comes from the same constants as its buffer, and no writer goes past its room. A byte array (`[u8](16)`, also `[u8](N)` of a length C computes) is read up to a NUL or its end, never past it, as `sizeof` of the array tells; one whose length is a number of at most `KV_TEMPLATE_STR` has room for all of it, and a longer one, or one whose length kelvinc cannot read, is cut as a string is. Inside a `?:`, C makes an array a pointer, which is read as a string. A string kelvinc cannot see the length of (`u8^`, `cstr`, C's `char *`, a template's text in a variable, `.cstr` of a string, `.typename`) and any value only C sees get `KV_TEMPLATE_STR` bytes, 256 unless a program sets `-DKV_TEMPLATE_STR=n` (at least 64, else an `#error`); a longer string shows its first `n - 3` bytes and `...`, read no further than `n + 1` bytes, and cut at a byte, as in P35. Each evaluation builds its text in a buffer of its own, the size of the storage, inside the statement expression (`KV_TEMPLATE_BUILD`), writing the parts and values in turn, and then copies it into the storage (`KV_TEMPLATE_TAKE`); so ``s := `${s}b` `` stops growing at `KV_TEMPLATE_STR + 1` bytes, each value that reads the earlier text being cut at `KV_TEMPLATE_STR`; every evaluation of one template returns the same storage, and a pointer kept from an earlier one shows the newest text. The stack holds the storage and, while it is built, its copy, and a struct's text is in its `.cstr` buffer too. The writers of libkelvin take the place to write at and a limit, and return the end: `kv_template_str(p, max, s)`, `kv_template_bytes`, `kv_template_copy` and the rest; `kv_template`, `kv_template_take` and `kv_template_free` are gone, and with them libkelvin's only `malloc`, `realloc`, `free` and out-of-memory abort |
| P57 | Details of #45 | `let main():i32 { ... }`, `static let half(n:i64):i64`, `let point.norm():f64` and `let +(a:vec, b:vec):vec`; `main():i32 {` is an error, "a function is declared with let: write 'let main(...)'" | At the top level, `let`, after `static` or `extern` if any, followed by a name and `(`, by a type, `.`, a name and `(`, or by an operator and `(`, declares a function, a method or an operator, a prototype too. Without `let` each is an error that shows where it goes, and so is `var` before one, which also shows `var f:(T):R := g` for a variable holding a function; a name and `(` that no parameters follow (`)`, `...`, `var` or `name:`), as a call or `_Pragma(...)`, is instead a statement out of place, an error that says so. Inside a function, `let f(` or `var f(` before parameters is an error that shows `let f:(T):R := { (a:T):R in ... }` (#32), and a C function-pointer declaration after `let` or `var` gets #31's message, as at the top level. The C is as before: a C function cannot change anyway, so `let` adds no `const`. Since a definition now starts with a keyword, the rule that an operator's head on a new line ended a value or a type before it (#42) is gone; a line that starts with an operator goes on with the line before, as everywhere (#35). Messages that show a function's head show `let` |
| P58 | Details of #46 | `#import <complex.k>` is `./modules/complex.k` if there is one, else `complex.k` in Kelvin's `modules/`; with `./modules/greet.h` and `./modules/libgreet.a`, `#import <greet.h> as C` and `KELVIN_CFLAGS=-lgreet` find them | Kelvin's own `modules/` is the first of `$KELVIN_HOME`, kelvinc's directory (the source tree) and its parent with `modules/kelvin_prelude.h`, or with `lib/kelvin/modules/kelvin_prelude.h` as `make install` lays it out; `libkelvin.a` must be beside it, else an error says to run `make`. `./modules` is relative to the directory kelvinc runs in, not to the program's file. kelvinc gives C `-I./modules -L./modules` where it is a directory other than Kelvin's own, after the `-I` of the `.k` file's directory, and `-isystem` and `-L` of Kelvin's, so C looks for a `<x.h>` next to the `.k` file, then in `./modules`, then in Kelvin's `modules/`, and the prelude's macros raise no warnings. A `./modules` that holds a `kelvin_prelude.h` of its own, another Kelvin's, is `-idirafter` instead, so that the prelude C reads is the one beside the `libkelvin.a` linked. kelvinc links only libkelvin, and `KELVIN_CFLAGS` now come after the program's C file, so that a `-lfoo` there links what the program uses, as GNU ld needs. `make` builds `modules/libkelvin.a` and `modules/libkelvin.so` or `.dylib`; the runtime's sources stay in `runtime/`, compiled with `-Imodules`. `make install` copies `kelvinc` to `$PREFIX/bin`, and the header, the libraries and `modules/*.k` to `$PREFIX/lib/kelvin/modules`, no longer to `$PREFIX/include` and `$PREFIX/lib`; C that uses libkelvin from there takes that directory's `-I` and `-L`. `tests/run.sh` builds a copy of `tests/project/` from inside it, so that its `modules/` is `./modules`, with `libanswer.a` built there from `answer.c` and linked through `KELVIN_CFLAGS=-lanswer`; and it builds `examples/complex.k` from a directory without `./modules`, with Kelvin's `modules/` laid out as `make install` does, by a kelvinc copied to its `bin/` and through `KELVIN_HOME` |
| P59 | Details of #47 | `var z = complex64(0.0, 1.0)` is `struct complex64 z = ...`; `let r := &q` of a let `q:point` is `const struct point *const r`; `let ap := arr` of `arr:[i32](3)` is `int32_t *const ap = arr` | A declaration without a type takes the type of its value as overloading sees it (P52), after the rules of #11, #24, #25 and #32: a Kelvin function's or method's result (the overload chosen, or the result all that C may choose have), a variable, a field of a Kelvin struct, `p^`, `a[i]`, `&x` (pointing to `const` where `x` is a let, or a let's field or element), a compound literal, a text property (`.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.typename` are `u8^`), a template's text (`u8^`), an enumerator (its enum), a character (`u8`), `sizeof` (`size_t`), a function's name of one overload (its function type), and a `?:` between two values of one type. An array is not copied in C, so its value is the pointer C makes of it, to `const` for a let. Not inferred, so needing a written type: arithmetic and the other operators (`+ - * / % & \| ~ << >>`, unary `- + ~`, `?:` between numbers of two types), whose type is C's promotion of the operands; a string literal (an array or a pointer, Q10); `.size` and `.addr`; and any value only C sees (a C function's result, a C struct's field, a macro, a name from a header). The `=` and `:=` check (#19) then applies to the inferred type: `var t = &x` is an error asking for `:=`. The message names what is and is not inferred |
| P60 | Details of #48 | `let a:[i32](3) = [1, 2, 3]`, `var g:bag = {1, [7, 8, 9], {5, 6}}`, `let sp:[i64](4) = [[2] = 9, [0] = 1]`, `([i32])[10, 20, 30]`, `for x in ([i32])[5, 6, 7] { }`; `let m = [[1, 2], [3, 4]]` is `[[i64](2)](2)` (types as #49 spells them) | An initializer list written `[...]` is an array's, `{...}` a struct's or union's, in a declaration, a member of a list, or a compound literal; both are C's `{ }`. Where kelvinc sees the type, the wrong brackets are an error with a hint: `{...}` for an array, `[...]` for a struct, a union, a scalar or a pointer. Where only C sees it (a C struct's member, a C typedef), either is accepted. Inside a list, an item that starts with `[` is a nested array unless `=` follows the group, which makes it a designator, `[2] = 5`; `.name =` designators are as in C. A compound literal of an array is `([T](N))[...]` or `([T])[...]`, told from `(p)[i]` by the parentheses holding a type that starts with `[` (a typedef name alone, `(vec3)[...]`, is read as an index), or a `v.type` kelvinc sees as an array; `sizeof` takes it. `[T]` with `[...]` of no designators is `[T](N)` to kelvinc, and `[[T]]` takes its inner count from the first row, which every row must match (a string row is an error asking for the count), N the items' count, so that `.size`, `for x in` and templates know it, in a declaration and in a compound literal; with designators, or a string, C counts as before. An array literal infers its type (#47): `[T](N)` where every item infers `T`, a nested list `[T](M)`, none designated and none a string; `let q := ([i32])[...]` inferred the pointer until #49, where it declares the array. In an expression, `[...]` is an error that shows the compound literal |
| P61 | Details of #49 | `var a:[i32](4)` is `int32_t a[4]`, `var m:[[i32](3)](2)` is `int32_t m[2][3]`, `let p:[i32](4)^ := &a` is `int32_t (*const p)[4]`, `var line = [u8](n)` is `uint8_t line[n]; memset(line, 0, sizeof line);`, `a.count` is `(sizeof(a) / sizeof((a)[0]))` | `[T]` is an array of T and `[T](N)` one of N elements, N any C constant or, for a local `var`, a value C computes at run time (a VLA, as `T[n]` was); a qualifier is the elements', `[const u8]`. Suffixes follow as before: `[T](N)^` is a pointer to the array, `[T^](N)` an array of pointers, `[[T](3)](2)` C's `T[2][3]`, indexed `m[1][2]`. A declaration with a value needs no count: `let a:[i32] = [1, 2, 3]`, `let s:[u8] = "hi"` (C counts the string), and `let a = [1, 2, 3]` (#48). `[T](n)` is also a value: n zero-filled elements, `(T[n]){0}` in C, or, declaring a local, `T a[n] = {0}`; where C computes n, the VLA is declared and then `memset`, so a `let` of such a count is an error (C cannot fill a const VLA). An array's compound literal, `([T])[...]`, declares the array itself where it initializes a declaration (#48 made it a pointer), and is a pointer where a pointer is declared. `a.count` is the number of elements, `sizeof(a) / sizeof a[0]`, right for a VLA too, a `size_t` as `.size` is; it is a property of an array kelvinc sees, a field where it sees a struct with one or cannot see the value, and an error on a pointer, where a parameter's count is passed beside it. `.size` is `sizeof` as before, `count * sizeof(T)`. `var p := a` is the pointer C makes of the array, and `p^` is `a[0]`. `T[N]`, `T[]` and `T[N]^` after a type are errors whose hint spells the type the new way, from the source as written (`u8[sizeof(buf)]` is `[u8](sizeof(buf))`), as does the hint for a C declaration (`size_t a[2][3]` suggests `var a:[[size_t](3)](2)`); `.typename` and messages spell arrays so. A `(` on the line after `[T]` starts a statement (#35), not a count. Not yet: a count that grows, and an array of functions |
| P62 | Details of #50 | `p.isNull` is `((bool)((p) == 0))`; `let z = p.isNull` infers `bool` | `.isNull` is a property of every pointer and function value kelvinc sees (as `.addr`, #37: `T^`, `any^`, `cstr`, a string literal, `nullptr`, a function value or name, `&x`, a property's text, a stepped pointer, a `?:` of pointers), a `bool`, so it infers `bool` and serves as a condition and under `!`, `&&` and `\|\|`. A Kelvin struct's field named `isNull` wins, and so does the field of a C struct or of a value kelvinc cannot see (`getenv("X").isNull` is C's member access, an error there: write `== nullptr`). An array is an error, since it is never null; any other value kelvinc sees is an error naming its type. C's `==` gives an `int`, so the C is cast to `bool`, as a comparison is (#23) |
| P63 | Details of #51 | `p++` is C's `p++;`, a statement; `for (var q := s; q^ != 0; q++)`; `c.p++`, `pp[1]++` | `p++` and `p--` are read where an assignment is: a statement of its own, a comma list, a `for` clause; inside an expression (`p++^`, `f(p++)`, `let q := p++`) they are an error saying so, and prefix `++p` is an error that shows `p++`. The target follows the rules of assignment (#27): a let, a range's counter, each element of a sequence or a let parameter cannot change. Where kelvinc sees the type, it must be a pointer other than `any^` (no element size): a number is told `x += 1`, an array that it does not move, a function that it is none. A type only C sees (a C typedef, a C struct's field) steps as C allows, so C rejects a const there. The C is `p++`, so the pointer is evaluated once, unlike `p := p.next` |
| P64 | Details of #52 | `var s:cstr := "hi"` is `const uint8_t *s = "hi"`; `s.count` is `(_kv_s_count == (size_t)-1 ? (_kv_s_count = strlen((const char *)s)) : _kv_s_count)` with `size_t _kv_s_count = (size_t)-1;` after `s`'s declaration; `var p:u8^ := s` is `uint8_t *p = (uint8_t *)s` | `cstr` is a pointer to `const u8` that kelvinc knows as text: its `.typename` is `cstr`, and so is a string literal's, a text property's (`.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.typename`), a template's and `&s[i]`'s; a string literal infers `cstr`. Writing through it (`s[i] = v`, `s^ = v`, compound assignments too) is an error naming the ways to change text; stepping it (`s++`, `s--`, `.next`, `.prev`, `s + n`, `n + s`, `s - n`, `s += n`) is an error naming `for c in s`, indexing and a `u8^` cursor; `s - t` between two texts, comparisons and `:=` of the reference stay. `s.count` is `strlen`: for a local or a parameter whose `.count` the function uses, a `size_t _kv_<name>_count` is declared, `(size_t)-1` until the first use measures it, after the declaration (a parameter's at the top of the body), and set back after `s := ...` as a statement; the scope is the block of the declaration. Any other receiver (a global, a field, a call) is measured at each use. A `cstr` given where a `u8^` to non-const `u8` is declared, assigned with `:=`, put in an initializer list, or passed to a Kelvin function (the one chosen, or the only one) is cast by kelvinc, as `s as u8^`; among overloads a `cstr` does not fit a `u8^` parameter, and a C function's `char *` parameter needs the `as`, as C would warn. A `u8^` into a `cstr` needs nothing. `cstr const` is a constant pointer; `const cstr` the same. In C the type is `const uint8_t *`, so libc's `const char *` parameters take it, and `main`'s `argv:[cstr]` is still written `char **` |
| P65 | Details of #53 | `let vector2d.cstr():cstr { `(${self.x}, ${self.y})` }` gives `enum { _kv_vector2d_cstr_size = sizeof "(" ", " ")" + 24 + 24 };` at the struct and `static inline uint8_t *_kv_vector2d_cstr(struct vector2d self, uint8_t *_kv_buf) { ...; kv_cstr_put(_kv_buf, `...`); return _kv_buf; }` where the method is | `T.cstr()` on a Kelvin struct or union, `cstr` being read as the method's name there, takes no parameters, gives a `cstr`, and has a body that is one template literal, or one string literal, with or without `return`; any other body, a prototype, a built-in receiver, or a second definition for one type is an error. kelvinc puts the size of its text, the template's room (#44), in the enum the derived text would have, at the struct, with a prototype, and defines the writer where the method is written: the template is built in the method's block as any template is, then copied into the caller's buffer, so the text lives as long as the derived text would, and `v.cstr`, `${v}` and the text of a struct that holds a `T` all use it. The derived writer is not emitted for such a type. The method is read as a property, `v.cstr`, not called; it is not a method name for `v.cstr()`. A template inside it may use `self`, globals and functions, as any template may, not the enclosing function's locals (#32) |
| P66 | Details of #54 | `var b = Bytes("hi")` is `__attribute__((cleanup(kv_bytes_free))) kv_bytes b = KV_BYTES_OF("hi");`; `return b` is `return kv_bytes_take(&b);`; `take(b)` is `take(kv_bytes_take(&b))`, and in the callee `int64_t take(kv_bytes _kv_d_in) { __attribute__((cleanup(kv_bytes_free))) kv_bytes d = _kv_d_in; ... }`; `b = f()` is `kv_bytes_assign(&b, f());`; `f();` is `kv_bytes_discard(f());`; `struct msg { body: Bytes }` gets `_kv_msg_free` and `_kv_msg_take` | `Bytes` is a keyword and a type kelvinc knows; in C `kv_bytes`, `{at, count, cap}`, `at[count]` a NUL, `at` NULL when empty. An owner is a `Bytes`, a Kelvin struct with an owner member (also in an array member), or an array of owners. A local or a parameter of an owner type, not `static`, gets the cleanup attribute; a `let` owner is `const` to kelvinc only, since C's free takes it; one declared without a value is `{0}`. A parameter of an owner type comes in by value as `_kv_<name>_in` and moves into a local of the name at the body's top. `=` and an initializer from a place of an owner type (a variable, a field, an element, `p^`) are errors; from an expression they take the value, freeing what the target held (`kv_bytes_assign`, or `_kv_T_free` then the assignment, for a local; a field or a global is C's assignment, which does not free). `return b` of a local owner is `kv_bytes_take(&b)` or `_kv_T_take(&v)`; a part, or `&b`, is an error. A local owner given by value to the Kelvin function chosen (one function of the name, or the overload chosen) moves with `kv_bytes_take`, and its binding is marked moved until an assignment to it, in every scope below; a global is an error; among overloads C chooses, an owner argument is not moved. A Bytes an expression gives, as a statement, is freed by `kv_bytes_discard`; used in a property, a method, an index, a loop or a comparison it is an error that says to bind it; a struct that owns, dropped, is an error. A borrow is `&b`: assigned to a variable of an outer block, or returned, an error. `b[i]` is `(*kv_bytes_at(&b, i))`, checked; `b.count`, `b.capacity`, `b.at` the fields, `b.cstr` `kv_bytes_cstr(&b)`; the methods call `kv_bytes_*`, `append` and `insert` through `_Generic` on the value (a byte, text, `kv_bytes *`, or a `kv_bytes` by value, which is freed); `==` is `kv_bytes_eq(&a, &b)`; `for x in b` walks `at` to `at + count`; `print`, templates and derived text have their `kv_bytes` cases. A C function may not take a Bytes; `print` and `println` may. A union with an owner member, and an array of owners as a variable, are errors. Growth doubles from 16; `compact` shrinks to the count, and frees an empty one; failure calls `abort` after a message on stderr |
| P67 | Details of #55 | `var s = String("héllo")` is `__attribute__((cleanup(kv_string_free))) kv_string s = KV_STRING_OF("héllo");`; `for c in s` is `for (const uint8_t *p = s.b.at, *const end = p + s.b.count; p < end; ) { const uint32_t c = kv_utf8_next(&p); ... }` | `String` is a keyword and a type; in C `kv_string`, `{kv_bytes b; size_t count}`, `b` well-formed UTF-8 and `count` its codepoints, kept as it grows. It is an owner (#54): the cleanup attribute, moves, no copy by `=`, borrows, a struct's derived free, no passing to C, all as for `Bytes`, through the same code (`builtin_owner`). `String()`, `String(text)` of a literal, a `cstr` or a byte array, `String(&b)` of a `Bytes`, and `b.string()` check the text with `kv_utf8_valid` (no overlong forms, no surrogates, nothing past U+10FFFF) and abort with a message where it fails; `b.isUTF8` is the check as a `bool`. `s.count` is the field; `s.bytes` is `(const kv_bytes *)&s.b`, a `const Bytes^` through which the methods that change a Bytes are errors; `s.cstr` is the bytes' text. `append`, also `+=`, takes text (checked), a codepoint (any integer; one that is no codepoint aborts), a `String^` or a `String` an expression gives (freed), through `KV_STRING_APPEND`'s `_Generic`; a `Bytes^` into a `String`, and a `String^` into a `Bytes`, are errors naming `b.string()` and `s.bytes`. `clear`, `reserve`, `compact`, `copy` as for `Bytes`; no `insert`, `remove` or `s[i]`, which would walk the text, and the error says so. `==` is `kv_string_eq`, both in variables. `for c in s` decodes as it goes, `c` a `u32`. `print`, templates, derived text and `.typename` ("String") have their `kv_string` cases. `print` of an owner an expression gives is an error, as nothing would free it (#54 too). `toString` and `fmt` stay no methods: the hint now names `x.cstr` and `String(x.cstr)` |
| P68 | Details of #56 | `for c in s` is `const kv_uchr c = (kv_uchr){kv_utf8_next(&p)};`; `uchr("é")` is `KV_UCHR_OF("é")`; `n.uchr` is `kv_uchr_of(n)`; `c.utf32` is `(c).cp`; `c == 'a'` is `(c).cp == 'a'` | `uchr` is a keyword and a type, a value of four bytes; in C `kv_uchr`, `{uint32_t cp}`, a struct so that `_Generic` tells it from a `u32`. `uchr(x)` of an integer, or `n.uchr` of an integer or a character, is the codepoint, U+FFFD where `x` is a surrogate or past U+10FFFF; `uchr(text)` is the first codepoint of text, U+FFFD for empty or malformed text; `uchr(c)` of a `uchr` is `c`. `c.utf32` and `c.codepoint` are the number, a `u32`; `u32(c)`, `i64(c)` and the other converters take the number too. A comparison with a `uchr` on either side compares the numbers, so `c == 'a'` and `c < d` work; any other operator is an error naming `.utf32`. `print`, templates (room for 4 bytes), `.cstr` (its UTF-8 with a NUL, in a buffer) and derived text show the character; `.typename` is `uchr`. `s += c` and `s.append(c)` append it. `for c in s` over a `String` gives a `uchr`. `.uchr` of a value that is no integer is an error; a field named `uchr` wins where kelvinc is unsure |
| P69 | Details of #57 | `var xs = Array<i64>()` is `__attribute__((cleanup(_kv_array_i64_free))) _kv_array_i64 xs = (_kv_array_i64){0};`, after `KV_ARRAY(int64_t, _kv_array_i64, KV_PLAIN_FREE, KV_PLAIN_COPY)` before the first top-level declaration that uses the type; `xs[i]` is `(*_kv_array_i64_at(&xs, i))`; `names[0] = String("x")` is `kv_string_assign(_kv_array_String_at(&names, 0), ...)` | `Array` is a keyword; `Array<T>` is a type, a `T_BASE` named `Array<T>` by the Kelvin spelling of `T`, with its C name `_kv_array_<T mangled>` (`Array_i64` inside another, as in `_kv_array_Array_i64`), recorded once per program in order of first use with the top-level declaration that first uses it, where its C is emitted, so that `T`'s struct is declared by then. `>>` closes two. `T` is any value type, a `Bytes`, a `String` or an `Array`; a fixed array, `any` and a struct that owns are errors. The prelude's `KV_ARRAY(T, A, FREE, COPY)` declares the struct `{at, count, cap}`, `A_free` (frees each element with FREE, then the storage), `A_take`, `A_assign`, `A_discard`, `A_reserve` (doubling from 16), `A_zeros`, `A_from`, `A_copy` (COPY of each element), `A_append`, `A_append_ref` (COPY of each of the other's), `A_append_owned` (the other's elements moved in, its storage freed), `A_at` (checked), `A_pop`, `A_insert`, `A_remove` (FREE of the removed), `A_clear` (FREE of all), `A_compact`; FREE and COPY are `kv_bytes_free`/`kv_bytes_copy` and the like for an element that owns, and no-ops for a plain `T`. The owner rules hold through the same code as `Bytes`'s (`builtin_owner` gives `"array"`): the cleanup attribute, moves, no copy by `=`, borrows, a struct's derived free, no passing to C. `xs[i]` is a place of type `T` (const for a let); `xs[i] = v` of an element that owns assigns through `kv_<T>_assign`, freeing the old. `for x in xs` is the Bytes loop over `at`; `x` is each element in turn, which cannot be moved or returned. `Array<T>(x)` is `A_zeros` of a number, `A_from` of a fixed array (its count from `sizeof`), `A_copy` of a borrow. `xs += x` and `append` take an element, `&other` of the same type (`append_ref`), or an `Array<T>` an expression gives (`append_owned`), chosen by kelvinc. `.size` is `sizeof`; `.typename` the spelling; `print`, templates, `.cstr` and `==` are errors naming the elements; a C function cannot take one. `Array<T>` with no `(...)` where a value goes is an error that says it is a type |
| P70 | Details of #58 | `var va = Array([0, 1, 2, 3])` is `_kv_array_i64 va = _kv_array_i64_from((int64_t [4]){0, 1, 2, 3}, 4);`; `Array(a)` of a fixed array is `_kv_array_i64_from(a, sizeof (a) / sizeof (a)[0])`; `Array(&xs)` is `_kv_array_i64_copy(&xs)` | `Array(` with no `<T>` is the constructor with `T` to infer. A `[...]` argument is parsed by kelvinc itself (`array_of_list`): each item that is not `[...]` is parsed as a fixed array's initializer item of `T` (an anonymous function, a struct's `{...}`), and an owner variable among them is rejected as `=` rejects it; an item that is `[...]` is `Array(...)` of it in turn, of `T`'s element type when `T` is given (an error when `T` is no Array), inferred otherwise, so `Array([[0], [1, 2]])` is `_kv_array_Array_i64_from((_kv_array_i64 [2]){_kv_array_i64_from((int64_t [1]){0}, 1), _kv_array_i64_from((int64_t [2]){1, 2}, 2)}, 2)`; `T` not given is the list's type by `list_type` (#48): every item a literal, a bool, a seen value or an Array, of one Kelvin type, else an error that asks for `Array<T>([...])`; `Array([])` asks for `Array<T>()`, and `Array<T>([])` is the empty Array. The element passes the checks of `Array<T>` (no fixed array, no `any`, no struct that owns). The count is the items', as `[T]`'s is (`count_items`); designators are an error. C gets a compound literal of the fixed array and the count, through `A_from`, which copies the elements' bytes: an owner written there (`String("a")`, `squares(3)`) is moved into the Array. `Array(a)` infers `T` from `a`'s element type, `Array(&other)` takes `other`'s type; `Array()`, `Array(n)` and `Array(x)` of anything else are errors that name `Array<T>(...)`. The checks and the C of `Array<T>(...)` (#57) are unchanged |
| P71 | Details of #59 | `var v:{x:f64, y:f64} = {3.0, 4.0}` is `struct _kv_anon1 v = {3.0, 4.0};` after `/* {x: f64, y: f64} */ struct _kv_anon1 { double x; double y; };` and its derived `.cstr`, before the top-level declaration that first writes the spelling; `Array<{x:f64, y:f64}>` is `_kv_array_anon1` | `{` where a type goes starts a struct with no tag: its members as a struct's (`parse_var`), separated by `,`, `;` or a line break, at least one. Its spelling is `{` + `name: T` per member, joined by `, `, + `}` with each `T` as kelvinc spells it; the first use of a spelling makes a `D_STRUCT` named `_kv_anonN` (N counting from 1 per program) with the spelling, registered as a record and pushed to the program's declarations at once, so that it precedes the top-level declaration being parsed and any `Array<T>` of it; a later use of the same spelling finds that record, so the type is `struct _kv_anonN` everywhere it is written. Messages and `.typename` spell it by its spelling; its mangled name is `anonN`. Codegen writes the spelling as a comment before the struct. Casts and compound literals, `({x:f64}){1.0}`, read the `{...}` as a type where `(` ... `)` holds one. A struct or union given a value of another struct or union kelvinc sees (a declaration's value, `=`) is an error that spells both the Kelvin way, since C's would name `_kv_anonN`. `_kv_` names are rejected where a type goes, as they are where a name is declared. Not yet: a method or an operator on one, a union with no tag |
| P72 | Details of #60 | `var u:union{i:i32, f:f32}` is `union _kv_anon1 u;` after `/* union{i: i32, f: f32} */ union _kv_anon1 { int32_t i; float f; };` | `union{` where a type goes is #59's record with no tag, a `D_UNION`, spelled `union{i: i32, f: f32}`; `struct{` spells #59's. Its text is `<union{i: i32, f: f32}>`; an owner member is rejected as in a tagged union |
| P73 | Details of #61 | `enum json { null; n: f64; s: String; a: Array<json> }` is `struct json { uint8_t tag; union { double n; kv_string s; _kv_array_json a; } u; };`, with `_kv_json_cases[]` (the names), `_kv_json_free`/`_take`/`_copy` when a case owns, and per case `_kv_json_at_n` (checked, a pointer), `_kv_json_get_n` (checked, by value), `_kv_json_set_n` (frees what it held) and `_kv_json_make_n`; `var j = json.n(1.5)` is `struct json j = _kv_json_make_n(1.5);`, `j.n` is `(*_kv_json_at_n(&j))` of a place and `_kv_json_get_n(f())` of a value, `j.n = x` is `_kv_json_set_n(&j, x)`, `j.is(n)` is `((bool)((j).tag == 1))`, `j.case` is `(j).tag`, `switch (j)` is `switch ((j).tag)` with `case 1: /* n */`, `{.n = 1.5}` is `{.tag = 1, .u.n = 1.5}` | A top-level `enum T {...}` whose braces hold a `:` at depth 1 is an enum with values: a `D_STRUCT` with `tagged`, its members the cases, a case with no value typed NULL; `= n` on a case and a case written twice are errors, and 255 is the most. Without a tag, `enum{...}` is #59's record, spelled `enum{i: i32, f: f32}`. `v.n` is an `E_FIELD` with op `case`, typed as the case; `v.none` (no value) is an error naming `.is` and `{.none}`; `v.case` is a `u8` property; `v.is(n)` takes a case name, not a value; `switch (v)` of one sets the record for its `case` labels, where a bare name that is a case is its index (any other label is as before). `v.n = x` is a `case_set` method: the value as a case's is `pick_overload`ed and `drop_cstr`ed, a `{...}` of a struct or array case is its compound literal, an owner place is rejected as `=` rejects it, and a local owner name given to `T.n(x)` moves (O5). `{.n = x}` and `{.none}` are the only initializers, one case; `{}` is the first case zeroed, as is a declaration without a value (`= {0}` in C). The derived text is `n(1.5)` or `none`, by a switch; its size is the sum of the cases'. A struct that owns gets `_kv_T_copy` (each member that owns copied with its copy, arrays of them in a loop) and `s.copy()` (`record_copy`), so an element that owns is allowed in `Array<T>` (COPY is `_kv_T_copy`); for an `Array<T>` of the struct or enum being declared, the prelude's `KV_ARRAY` is split into `KV_ARRAY_TYPE` (before the declaration, with `T *at` of the incomplete type) and `KV_ARRAY_FUNCS` (after it, with prototypes of `_kv_T_free` and `_kv_T_copy`, which they call). `kv_case_fail(type, want, have)` in the runtime prints `case 'n' of json is not current: it is 's'` and aborts. Not yet: a `case` label that binds the value, an anonymous enum with values at the top level, methods and operators on one with no tag |
| P74 | Details of #62 | `var s = $"I needed it"` is `kv_string s = KV_STRING_OF("I needed it");`, `var m = $[[1, 0], [0, 1]]` the C of `Array([[1, 0], [0, 1]])` (P70) | The lexer already makes `$` a token of its own before `"` or `[`. In an expression, `$` before a string literal is `String(...)` of it (adjacent literals join as they do), and `$` before `[` is `Array([...])` through the same code (`array_of_list`), with the same inference and errors; except that, while an anonymous function is being parsed, `$[` a number `]` is its parameter, as before, so `$[1]` there is parameter 1 and `Array([1])` the Array. `$` before anything else says what `$` makes |
| P75 | Details of #63 | `switch n { case 0: a() case 1, 2: b() default: c() }` is `switch (n) { case 0: a(); break; case 1: case 2: b(); break; default: c(); break; }`; a switch exhaustive by its cases ends with `default: __builtin_unreachable();` | The subject is an expression where `{` ends it, as a condition is (parentheses group); the body is a block whose statements are checked: it starts with a case; a case label is one or more values separated by `,` (of an enum with values, a case's name; of anything else, C's constant expression); a case or `default:` directly followed by another is an error; `case` and `default:` are only at the top of a switch's block (the depth of the block is counted); with no `default:`, the subject must be an enum with values whose every case is a label, or a Kelvin enum whose every enumerator is a label (an `E_IDENT` of its name), else the error names what is missing. The implicit-value check of a function's last statement now looks at every case's last statement, since each ends the switch. Codegen writes each case's statements in a block of their own (so a declaration in one case is its own, as #65's JSON test needed), ending with `break;` unless the last statement is `break`, `continue`, `return` or `goto`, and `default: __builtin_unreachable();` for one exhaustive by its cases. Not yet: ranges and patterns in a label, `fallthrough` |
| P76 | Details of #64 | `var va:$[[i64]]` is `_kv_array_Array_i64 va = {0};`, as `Array<Array<i64>>` is | In a type, `$` followed by `[` is an Array of the type inside, through `array_type` with the element checked as `Array<T>`'s is; a `[` inside the brackets is an Array again (`parse_dollar_array` recurses), while any other type inside, a struct's members included, is parsed as usual; `(n)` after the element is an error, since an Array has no count in its type. The type scanners read `$[...]` as a type, so it goes in parameters, results, members, anonymous functions' signatures and `($[T]){...}`; its spelling and `.typename` are `Array<T>`'s. `$` before anything else where a type goes is an error that names `$[T]`. Found on the way: `xs[i]` of an Array or a Bytes that an expression gives (`rows()[0]`) is now an error, as `.count` of one was, since nothing would free it |
| P77 | Details of #65 | `var ages = $["ann": 31]` is `_kv_dict_String_i64 ages = ({ _kv_dict_String_i64 _kv_d = {0}; _kv_dict_String_i64_set(&_kv_d, "ann", 31); _kv_d; });` after `KV_DICT(kv_string, const uint8_t *, int64_t, _kv_dict_String_i64, KV_HASH_TEXT, KV_EQ_TEXT, KV_STORE_TEXT, KV_MISSING_TEXT, kv_string_free, kv_string_copy, KV_PLAIN_FREE, KV_PLAIN_COPY)`; `ages["cy"] = 7` is `_kv_dict_String_i64_set(&ages, "cy", 7)`, `ages["ann"]` is `(*_kv_dict_String_i64_at(&ages, "ann"))`, `ages[s]` of a String `s` passes `s`'s text; `for k, v in ages` walks the entries array, skipping removed ones | `Dictionary` is a keyword; `Dictionary<K, V>` and `$[K: V]` are one `T_BASE` named `Dictionary<K, V>` with `key`, `elem` and the C name `_kv_dict_<K>_<V>`, recorded with the Arrays for its C, emitted before the first top-level declaration that uses it, in two parts around a struct or enum that holds one of itself (as #61 has it for Arrays). `K` is an integer type (i8 to u64) or `String` (a `cstr` says to write `String`), `V` what an Array holds. The prelude's `KV_DICT(K, LK, V, D, HASH, EQ, STORE, MISSING, KFREE, KCOPY, VFREE, VCOPY)` keeps entries `{key, value, hash, next, live}` in an array in the order added, a chain per bucket in `head` (index + 1, 0 the end) with twice the entries' capacity of buckets, growing from 16 and doubling, compacting removed entries on growth; `_lookup` compares hashes first; `_set` frees a replaced value; `_remove` unlinks, frees and marks dead; `_copy` copies keys and values with their copy functions. The key given (`LK`) is the integer, or a `const uint8_t *` for String keys, hashed by FNV-1a (`kv_hash_text`) or a 64-bit mix (`kv_hash_int`); a missing key ends the program through `kv_dict_missing_int`/`_text`. In Kelvin, `d[k]` is an `E_INDEX` with op `dict`, its key converted by kind (a String place gives its `.cstr`; text or an integer is checked); `d[k] = v` is a `set` method with the value as a case's is (#61); `+=` on `d` itself is an error. `$[k: v]` is read by `dict_of_list` (from `array_of_list` when `:` follows the first item, or when the written type is a Dictionary, also as a declaration's initializer), `K` from the first key (a cstr literal is a String key), `V` from the first value, every other entry alike; `$[:]` needs the type written. `for k, v in d` is `S_FOR_EACH` with `EACH_DICT`, `k` and `v` `LET_EACH` views, unused-ok in C; `for k in d` the keys. Methods are in the owner methods table with kind `d`; `find` gives `V^`, `const V^` for a let; `get` of a `V` that owns says to use `find`. No text, no `==`, no `+=` |
| P78 | Details of #66 | `var ks = ages.keys` is `_kv_array_String ks = _kv_dict_String_i64_keys(&ages);` after `static inline _kv_array_String _kv_dict_String_i64_keys(const _kv_dict_String_i64 *d)`, which reserves `d->count` and copies each live entry's key with the key's copy (`kv_string_copy`, or the bytes); `values` the same with the value's copy | `keys` and `values` are properties of a Dictionary in a place, typed `Array<K>` and `Array<V>` (`array_type` of the key or value, so the Array's C is emitted too); each first use is recorded with the top-level declaration that holds it, and its function is written before that declaration, after the Arrays' and Dictionaries' C of the same place. Their result is an Array an expression gives: bound to a variable, moved by passing, and not indexed or counted unbound, as any such Array |
| P79 | Details of #67 | `` var s = $`Hello, ${name}! ${n}` `` is `kv_string s = ({ kv_string _kv_s = kv_string_new(); kv_string_append_text(&_kv_s, "Hello, "); kv_string_append_text(&_kv_s, name); kv_string_append_text(&_kv_s, "! "); kv_string_append_text(&_kv_s, <n's .cstr text>); _kv_s; });` | `$` before a template literal (one with `${...}`; a plain backquoted text is a string literal, so `` $`plain` `` is `$"plain"`) is the template parsed as before (its values checked as #39 checks them, a struct's turned into its `.cstr`), with op `string`: its type is `String`, it is no text in a buffer, and each value is wrapped by how it is appended: a String place by reference (`kv_string_append_ref`), a Bytes place by its `.cstr` text, a `uchr` by `kv_string_append_uchr`, text (a literal, a nested template, a text property, a cstr) as it is, and anything else by its `.cstr` text, made in the block's buffer as a property's is; a String or Bytes an expression gives is rejected, as nothing would free it. The C is a statement expression that appends each part and value into a new String, with no bound: `kv_string_append_text` grows the String |
| P80 | Details of #68 | `var ys = xs[1..<3]` is `_kv_array_i64 ys = _kv_array_i64_slice(&xs, 1, 3);`, `xs[1...3]` passes `(3) + 1`, `xs[2...]` passes `(xs).count`, `xs[..<2]` passes 0; `s[1..<5]` is `kv_string_slice(&s, 1, 5)`, `b[2..<4]` `kv_bytes_slice(&b, 2, 4)` | In `[...]` after an Array, a String or a Bytes in a place, a `..<` or `...` before, after or between the bounds makes a slice (an `E_INDEX` with op `slice`): `[lo..<hi]`, `[lo...hi]`, `[lo...]` (to the count), `[..<hi]`, `[...hi]`; `[lo..<]` is an error; the bounds are integers; the result is a value of the same type an expression gives, not a place, so it is bound or moved, never indexed unbound. `A_slice` (in `KV_ARRAY_FUNCS`) copies the elements with the Array's COPY; `kv_string_slice` walks to the codepoints and copies their bytes, `kv_bytes_slice` the bytes; `lo > hi` or `hi > count` ends the program with `range lo..<hi is out of range: the Array has n`. Not yet: a slice that borrows, negative or from-the-end indices |
| P81 | Details of #69 | `var d = ${"ann": 31}` is the C of #65's `$["ann": 31]` | `$` before `{` is a Dictionary's entries, read as before between braces; `${:}` is the empty one where the type is known; `Dictionary<K, V>({k: v})` and `({...})` with `$` both work; a declared Dictionary takes `{k: v, ...}` or `${k: v, ...}` as its initializer, and a value of a Dictionary type inside another takes `{...}` when the type is written. `$[k: v]` and `$[:]` are errors that name the braces. The type followed in #70 |
| P82 | Details of #70 | `var d:${String: i64}` is `_kv_dict_String_i64 d = {0};` | `$` before `{` where a type goes is `${K: V}`: `K`, `:`, `V`, `}`, each type as it is written anywhere (`$[T]` an Array, `${...}` a Dictionary, `{...}` a struct with no tag); `(n)` after `V` says an Array has no count. `$[K: V]` is an error that names the braces. The spelling in messages is `Dictionary<K, V>`. The type documents each end with "Properties and methods", a table of what the type has; properties.md keeps `.size`, `.type`, `.typename`, `.cstr`, the number texts, `.addr` and `.isNull` in detail, and indexes the tables. Found on the way: a string literal where a String is expected (a typed declaration or assignment, a struct member, an Array's element, a Dictionary's value, a case's value) reached C as a `char[]` into a `kv_string`; it is now `String("...")` of it (`string_of_literal`) |
| P83 | Details of #71 | `var s = ${3, 1, 4}` is `_kv_set_i64 s = ({ _kv_set_i64 _kv_s = {0}; _kv_set_i64_insert(&_kv_s, 3); ... _kv_s; });` after `KV_SET(int64_t, int64_t, _kv_set_i64, KV_HASH_INT, KV_EQ_INT, KV_STORE_INT, KV_LK_INT, KV_PLAIN_FREE, KV_PLAIN_COPY)`; `s += 9` is `_kv_set_i64_insert(&s, 9)`, `s += &t` `_kv_set_i64_insert_all(&s, &t)`, `s.union(&t)` `_kv_set_i64_union(&s, &t)` | `Set` is a keyword; `Set<T>` and `${T}` are one `T_BASE` named `Set<T>`, with `key` and `elem` both `T` and the C name `_kv_set_<T>`, recorded with the Arrays for its C, emitted before the first top-level declaration that uses it, in two parts around a struct or enum that holds one of itself. `T` is what a Dictionary's key is. The prelude's `KV_SET(K, LK, S, HASH, EQ, STORE, LKOF, KFREE, KCOPY)` is the Dictionary's shape without values, `LKOF` giving the key given back from the key kept for the algebra: `_insert` (false when there), `_has`, `_remove`, `_clear`, `_copy`, `_insert_all`, `_union` (a copy plus the other), `_intersection`, `_difference`. `${...}` is read by `dict_of_list`, which hands over to `set_of_list` when no `:` follows the first item, or when the written type is a Set; `${}` is the empty Set of a written type, `${:}` with a Set type and `${}` with a Dictionary type say so. Methods are in the owner methods table with the letter `t` (`owner_letter`, since "set" starts as "string" does); `.union` is accepted as a member name though `union` is a keyword; the algebra checks its argument is `&other` of the same Set. `s.elements` is a view like `d.keys` (#66). `for x in s` is the Dictionary's loop with the key alone. No text, no `==`, no indexing, no `for k, v in s` |
| P84 | Details of #72 | `var a:i64? = 3` is `struct _kv_opt_i64 a = _kv__kv_opt_i64_make_some(3);` after `/* i64? */ struct _kv_opt_i64 { uint8_t tag; union { int64_t some; } u; };` and its functions (#61); `a = none` is `_kv__kv_opt_i64_set_none(&a)`; `a.some` is `(*_kv__kv_opt_i64_at_some(&a))`; `a ?? 0` is `(((bool)((a).tag == 1)) ? (*_kv__kv_opt_i64_at_some(&a)) : 0)` | `T?` and `Optional<T>` make, per spelling, a tagged record (#61) named `_kv_opt_<T mangled>` with the spelling `T?`, the cases `none` (no value) and `some: T`, registered as a struct with no tag is (#59): pushed to the program's declarations before the one being parsed. `?` is a type suffix, also after `^` and `]`, except after `as` (where `?` is a condition); in the type scanners, `?` is a suffix unless an operand follows it on the same line; `??` after a type is two. `T` is any value type but an array or a function type. A value where a `T?` is expected (a typed declaration, `=`, a struct member, an element, an entry, a case's value, `return`) is wrapped by `optional_of`: `none` (an identifier with no binding) becomes `make_none`, a `T?` stays, anything else becomes `make_some` of it after the String and `T??` wrappings, with a move for an owner; a `{...}` initializer of a `T?` is the `T`'s, wrapped. `x ?? y` is parsed after a conditional's left side, lowest in the expression: the left must be an Optional in a place (it is read twice), its `T` must not own, and the result is `is(some) ? .some : y`. `Optional<T>(v)` and `Optional<T>()` are the same wrapping. Everything else is the enum's: `.some`, `.some = v`, `.is`, `.case`, `switch`, `.cstr`, `.copy`, moves. Not yet: `x!`, `if let`, `== none`, `??` of an owner |
| P85 | Details of #73 | `var u = s \| t` is `_kv_set_i64 u = _kv_set_i64_union(&s, &t);`; `s ~= t` is `_kv_set_i64_symdiff_with(&s, &t)` | `\|`, `&` and `~` between two Sets of the same elements, both in places, are the methods `union`, `intersection` and `symdiff` with a borrow of the right side; `\|=`, `&=` and `~=` are `insert_all`, `intersect_with` and `symdiff_with` (the prelude gained `_symdiff`, `_intersect_with` and `_symdiff_with`), of a Set in a place on the right. A Set an expression gives on either side is an error that says to bind it, since its storage would need freeing |
| P86 | Details of #74 | `if let v = r { ... } else { ... }` of a variable `r` is `{ __auto_type _kv_v_opt = &(r); if (_kv_v_opt->tag == 0) { __attribute__((unused)) const int64_t v = _kv_v_opt->u.ok; ... } else ... }`; of a call, `__attribute__((cleanup(..._free))) struct _kv_opt_String _kv_n_opt = first(&names);` when the value owns, then `.tag` and `.u.some` | `if let` reads a name, `=`, an expression where `{` ends it, which must be an Optional or a Result; the value case (`some` or `ok`) names what is bound: a let with the ownership of a loop's element (`LET_EACH`, cannot be moved or returned), typed as the value, unqualified. The expression is read once: a place (a variable, a member, an element, a dereference) through a hidden pointer, anything else into a hidden variable of its type, freed by its block when it owns. `else` and `else if` follow as an `if`'s. Not yet: `if let` of the error, `while let`, `guard` |
| P87 | Details of #75 | `var r:Result<i64, String> = 1` is `struct _kv_res_i64_String r = _kv__kv_res_i64_String_make_ok(1);` after `/* Result<i64, String> */ struct _kv_res_i64_String { uint8_t tag; union { int64_t ok; kv_string err; } u; };` and the functions of #61; `err($"x")` is `_kv__kv_res_i64_String_make_err(KV_STRING_OF("x"))` | One maker, `variant_type(kind, a, b)`, builds the tagged record of a Result (`_kv_res_<T>_<U>`, cases `ok: T`, `err: U`) and of an Optional (`_kv_opt_<T>`, cases `none`, `some: T`), per spelling, registered as a struct with no tag is; `value_case` is `ok` or `some`. A value where either is expected (`optional_of`, at every site #72 named) is wrapped into the value case, `none` into `none` of an Optional, and `ok(v)`/`err(e)` into those cases of a Result: a call of `ok` or `err` with one argument and no function or variable of that name in sight is read as a word (op `word`) and never reaches C; a word of the wrong kind says so. `??`, `if let`, `{...}` initializers and `.is`/`switch`/`.cstr` take the value case by name. `Optional<T>.some(v)`, `Optional<T>.none`, `Result<T, U>.ok(v)`, `Result<T, U>.err(e)`, `Optional<T>(v)`, `Optional<T>()` and `Result<T, U>(v)` are read by one constructor. `x ?? y` now carries the value's type, so `var v = x ?? 0` infers. Of a `cstr?`, `u8^?` or `i8^?`, a `y` that is a string literal or text of another spelling (`u8^` beside `i8^`) is cast to the value's type, `(const uint8_t *)"unset"`, since C's `?:` of a `const uint8_t *` and a `char *` is no text: gcc refused it and clang made it an address (found by examples/results.k) |
| P88 | Details of #76 | `let n = try parse(s)` is `const int64_t n = ({ __attribute__((cleanup(_kv__kv_res_i64_String_free))) struct _kv_res_i64_String _kv_t = parse(s); if (_kv_t.tag != 0) return _kv__kv_res_i64_String_make_err(_kv__kv_res_i64_String_take(&_kv_t).u.err); _kv__kv_res_i64_String_take(&_kv_t).u.ok; });` | `try` is an E_CAST with op `try` (as the converters are), its type the value case's, its `from` the operand's Result or Optional, its `recv_type` the function's result; the parser checks the function's result is the same kind with the same `err` type (by spelling), and rejects a place whose value owns, since `try` would move it out. The C is a statement expression: of a value a call gives, a temporary with the record's cleanup when it owns, so that an early `return` out of the expression frees it; of a place, a pointer to it. The err, and an owner value, move out through the record's `_take`, which zeroes it, so neither the temporary's cleanup nor the place frees what moved; a non-owner is read in place. The function's `err` is made by `_make_err` (`_make_none` for an Optional) and returned by C's `return` inside the expression, which runs every cleanup of the function. A bare `try f()` statement omits the value, so an owner value stays in the temporary and its cleanup frees it. `return {0, 0}` of a `Result<point, U>` is still not wrapped (a declaration's is) |
| P89 | Details of #77 | `return {5, 6}` of a `Result<point, cstr>` is `return _kv__kv_res_point_cstr_make_ok((struct point){5, 6});`, of a `point` `return (struct point){0, 0};`, of `enum json` `return (struct json){.tag = 0, .u.n = 0.5};` | In `return`, a `{` where the function's result is a Kelvin or C struct or union, or a Result or an Optional, and no anonymous function's signature follows, goes to `parse_initializer_for` with the result type: for a Result or an Optional it gives the value's compound literal wrapped by `optional_of`, as a declaration gets; for a record, the list becomes a compound literal of the result type, which for an enum with values carries the tag. A function type result keeps `return { ... in ... }` for an anonymous function, and any other result (a number, a pointer, an Array) still says a list is not a value |
| P90 | Details of #78 | `if let err(e) = r { ... }` is `{ __auto_type _kv_e_opt = &(r); if (_kv_e_opt->tag == 1) { const kv_string e = _kv_e_opt->u.err; ... } }`, the C of #74 with the case's index and member | After `if let`, a name followed by `(` is a case's name, then the bound name and `)`; the record is `tagged_record` of the value's type (a Result, an Optional, or an enum with values), not only `variant_record` as for `if let v = e`; the case is found by name, must carry a value, and its index is the statement's `each`, so the codegen of #74 serves unchanged. Errors: a type with no such case lists its cases, a case with no value says to test `.is(case)`, a value that is no enum with values says so |
| P91 | Details of #79 | `a == b` of two `i64?` is `_kv__kv_opt_i64_eq(a, b)` after `static inline bool _kv__kv_opt_i64_eq(const struct _kv_opt_i64 a, const struct _kv_opt_i64 b) { if (a.tag != b.tag) return false; switch (a.tag) { case 1: return a.u.some == b.u.some; default: return true; } }`; `a != b` is `!_kv__kv_opt_i64_eq(a, b)`; `x == none` is `_kv__kv_opt_i64_eq(x, _kv__kv_opt_i64_make_none())` | When a tagged record is complete, the parser sets `no_eq`, the first case whose value has no `==` (an array, a struct or union, a C struct, an Array, a Dictionary, a Set, or an enum with values with a `no_eq` of its own); numbers, bools, pointers, functions, `uchr`, String, Bytes, C typedefs kelvinc cannot see and enums with values that compare are fine. For a record with no `no_eq`, the C gets `_kv_<name>_eq(a, b)`, by value, after its `_copy`: a String's and a Bytes's case by `kv_string_eq`/`kv_bytes_eq`, a `uchr`'s by `.cp`, a nested record's by its `_eq`, the rest by `==`. In `parse_binary`, `==`/`!=` with a tagged record on either side wrap the other through `optional_of` (so `none`, `ok(v)`, `err(e)`, a `T` and a literal into a String), check both are of one type, and, when the record owns, that each side is a place or a case made on the spot whose value does not own (`none`, `ok(5)`), since a value passed by value is never freed; the call is an E_CALL of op `c` with the two sides. Other operators on a tagged record say to compare with `==` and `!=` |
| P92 | Details of #80 | `a.map(twice)` of an `i64?` is `({ struct _kv_opt_i64 _kv_t = a; _kv_t.tag == 1 ? _kv__kv_opt_i64_make_some(twice(_kv_t.u.some)) : _kv__kv_opt_i64_make_none(); })`; of a `parse(s)` that owns, the temporary has the record's cleanup and what `f` takes, or what carries over, comes out through `_take`, so the cleanup frees nothing of it | `.map` and `.mapErr` on a Result or an Optional (`variant_record`) are read before the general method call: the one argument is inside the parentheses or a trailing `{ ... }`, an anonymous function then taking its parameter from a function type `(T)` made for it, with no result; a flag, `infer_anon_result`, lets `parse_anon_fn` give it the type of its one expression (`inferred_type`), or say to write the parameters and the result. The function's type must be `(T):U`, by spelling; the new type is `variant_type` of `U` with the other case's type; the method is an E_METHOD of op `map` or `map_err` with `from` the operand's type and `target` its record, typed for inference. A place that owns is rejected, as for `try`, since `f` takes the value by value, and the err would move too |
| P93 | Details of #81 | `a.flatMap(half)` of an `i64?` is `({ struct _kv_opt_i64 _kv_t = a; _kv_t.tag == 1 ? half(_kv_t.u.some) : _kv__kv_opt_i64_make_none(); })`, the C of #80 with `f`'s result in place of `_make_some(f(...))` | `.flatMap` is read by the branch of #80 with op `flat_map`: the function's result must be a variant of the operand's kind, and of a Result, one whose `err` type has the same spelling; the method's type is the function's result type itself. In the codegen, the applied function is the value where `map` wraps it; the other case is made of the new record as before. A trailing `{ ... }` infers its result from the one expression, which is a call here. Found on the way, and fixed: a function whose one expression gave an owner, as `{ (n:i64):String in $`#${n}` }` or `{ positive($0) }`, was refused as dropping it, since an expression statement that gives an owner was judged when parsed; now such a statement is noted (`pending_drops`) and judged when the body ends, after `implicit_return` has made the one expression the result (`finish_drops`): a Bytes, String, Array, Dictionary or Set is then freed at once, a struct that owns refused, as before |
| P94 | Details of #82 | `let f = try IO(path, "r")` is `const kv_io f = ({ ... ({ kv_io _kv_f = {0}; int _kv_e = kv_io_open(&_kv_f, path, "r"); _kv_e ? _kv__kv_res_IO_i32_make_err(_kv_e) : _kv__kv_res_IO_i32_make_ok(_kv_f); }) ... })` with `try`'s C, after `__attribute__((cleanup(kv_io_free)))` where it is a var; `for line in f.lines { }` is `{ __attribute__((cleanup(kv_string_free))) kv_string _kv_line_buf = {0}; kv_io *const _kv_line_io = (kv_io *)&(f); while (kv_io_read_line(_kv_line_io, &_kv_line_buf)) { const kv_string line = _kv_line_buf; ... } }`; `IO.stdout.write("x")` is `kv_io_write_text((kv_io *)&(*kv_io_std(1)), "x")` | `kv_io` is `{ void *fp; bool owned; }` in the prelude, a `void *` so that the prelude needs no `<stdio.h>`, whose names a program may declare itself (tests do); runtime/io.c casts. `IO` is a keyword and a base word, a builtin owner of kind `io`, letter `i`, with `kv_io_free`, `kv_io_take` and a `kv_io_copy` that aborts, since derived copies of structs would call it; `IO` is not comparable (`no_eq`). `IO(path, mode)` is an E_CALL of op `io` typed `Result<IO, i32>` through `variant_type`, a String or Bytes argument read through `.cstr`; `IO.stdin`/`stdout`/`stderr` an E_CALL of op `io_std`, `(*kv_io_std(k))`, a place in C, so that methods and properties work on it unbound, and a statement may start with it. Methods `write` (classified at parse into `write_text`, `write_bytes`, `write_string`, `write_owned_bytes`, `write_owned_string`), `flush` and `read` change nothing of the IO, so a let takes them, and the receiver is cast from const; `close` sets the IO's fp to NULL, so it needs a var: CI's glibc found a double fclose when a test closed through the copy that `if let ok(f)` binds, which macOS had tolerated. `f.bytes` and `f.string` are E_PROPERTY of op `io` typed as Results, read through `kv_io_read_all`/`kv_io_read_string` into a temporary; `f.lines` and `f.read(n)` have no type and are read by `for` alone: EACH_IO_LINES and EACH_IO_READ, the loop owning one String or Bytes with a cleanup, refilled by `kv_io_read_line`/`kv_io_read_chunk`, which the loop variable, a let, borrows |
| P95 | Details of #83 | `f.println("n = ", n)` is `KV_FPRINTLN((kv_io *)&f, "n = ", n)`, which is `({ void *_kv_fp = kv_io_fp(&f); kv_fprint_n2(_kv_fp, "n = ", n); kv_fprint_newline(_kv_fp); })`, each value through `KV_FPRINT1`, the `_Generic` of `kv_print1` over `kv_fprint_*` | Every `kv_print_x(v)` of the runtime is now `kv_fprint_x(void *fp, v)` to a FILE, with `kv_print_x` calling it with stdout; the FILE is a `void *`, as `kv_io`'s, so the prelude needs no `<stdio.h>`. `kv_io_fp` gives an IO's FILE, or aborts on a closed one, once per call, so the IO is evaluated once. `print` and `println` are IO methods of arity -1 in the parser's table, the first variadic ones, checked as `check_print_args` checks print: no function, at most 16 values |
| P96 | Details of #84 | `f.seek(8)` is `kv_io_seek((kv_io *)&f, 8)`, `f.eof` `kv_io_eof((kv_io *)&f)`, `f.count` `kv_io_count((kv_io *)&f)` | In runtime/io.c, `kv_io_eof` is `feof`, `kv_io_position` `ftell` (-1 on failure), `kv_io_count` seeks to the end and back, `kv_io_seek` is `fseek` from the start of an offset in `[0, LONG_MAX]`, `kv_io_rewind` is `rewind`; `seek` and `rewind` are IO methods that change nothing of the IO, so a let takes them; `eof`, `position` and `count` are properties of op `io` typed `bool`, `i64`, `i64` |
| P97 | Details of #85 | `f.i64` is `({ long long _kv_v = 0; kv_io_read_i64((kv_io *)&f, &_kv_v) ? _kv__kv_opt_i64_make_some(_kv_v) : _kv__kv_opt_i64_make_none(); })` | `kv_io_read_byte` is `fgetc`, `kv_io_read_i64` and `kv_io_read_f64` are `fscanf` with `%lld` and `%lf`, true when one was read; `byte`, `i64` and `f64` are IO properties of op `io` typed `optional_type` of `u8`, `i64`, `f64`; a converter name on an IO other than these says what an IO reads, before the text converters' branch, which an IO skips |
| P98 | Details of #86 | `IO(fd, "r")` is `({ kv_io _kv_f = {0}; int _kv_e = kv_io_fdopen(&_kv_f, fd, "r"); _kv_e ? _kv__kv_res_IO_i32_make_err(_kv_e) : _kv__kv_res_IO_i32_make_ok(_kv_f); })`, `f.fd` `kv_io_fd((kv_io *)&f)` | In the `IO(...)` branch, a first argument that is a number or of an integer type marks the call `fd` (an IO there says to write `f.fd`), and the mode alone is checked as text; the codegen then calls `kv_io_fdopen`, which is `fdopen`, EBADF where it fails without errno. `fd` is an IO property typed `i32`, `fileno`, -1 of a closed IO. runtime/io.c defines `_POSIX_C_SOURCE 200809L` before its includes, since glibc hides `fdopen` and `fileno` under `-std=c11`; programs need no such thing, as the prelude declares the runtime's functions itself |
| P99 | Details of #87 | `IO.popen(cmd, "r")` is `({ kv_io _kv_f = {0}; int _kv_e = kv_io_popen(&_kv_f, cmd, "r"); ... })` as `IO(path, mode)` is; `IO.pipe()` is `({ struct _kv_anon1 _kv_p = {0}; int _kv_e = kv_io_pipe(&_kv_p.reader, &_kv_p.writer); _kv_e ? _kv__kv_res__kv_anon1_i32_make_err(_kv_e) : ..._make_ok(_kv_p); })` | `kv_io` now holds `kind` (0 a stream never closed, 1 a file, 2 a process) and `status` in place of `owned`; `kv_io_free` runs `pclose` for a process and keeps `WEXITSTATUS` in `status`, or -1. `IO.popen` is read in the `IO.` branch with the text checks of `IO(path, mode)`, an E_CALL of op `io` with text `popen`; `IO.pipe()` an E_CALL of op `io_pipe` typed `Result<{reader: IO, writer: IO}, i32>`, the record made by `pipe_type` and registered as an untagged struct written in the program is, so that its derived free closes both ends. `status` is an IO property typed `i32` |
| P100 | Details of #88 | `i64(line)` of a String is `kv_text_i64(kv_bytes_cstr(&(line).b), 10)`, as `i64(line.cstr)` is; `f.i64` is an error naming `.byte`, `.lines`, `.read(n)` and `.string` | `kv_io_read_i64` and `kv_io_read_f64` are removed from runtime/io.c and the prelude, with the `i64` and `f64` IO properties; a converter name on an IO is refused where it was read before. In `convert`, a String or a Bytes in a variable becomes its `.cstr` borrow before the converter reads it, so every converter, `.i64` and `i64(s, 16)` included, takes one; one that an expression gives says to bind it first, since the text would be freed under the reader |
| P101 | Details of #89 | `p.ok.signal` is `kv_io_signal((kv_io *)&(*_kv__kv_res_IO_i32_at_ok(&p)))` | `kv_io` gains `signal`, -1 from every opener and for the standard streams, set with `status` when `kv_io_free` runs `pclose` on a process: `WTERMSIG` when `WIFSIGNALED`, else 0, -1 when `pclose` fails. `signal` is an IO property typed `i32`, as `status` is |
| P102 | Details of #90 | `IO.exec(["printf", "x"], "r")` is `({ kv_io _kv_f = {0}; int _kv_e = kv_io_exec(&_kv_f, (const char *const[]){(const char *)("printf"), (const char *)("x"), NULL}, "r"); ... })`; of an Array `args`, `kv_io_exec_cstrs(&_kv_f, (const uint8_t *const *)(args).at, (args).count, "r")`, of one of Strings `kv_io_exec_strings` | `kv_io_exec` makes two pipes, the data pipe and a report pipe with `FD_CLOEXEC`, flushes every stream, forks, and in the child dups the data pipe onto 1 or 0 and `execvp`s; where exec fails, the child writes errno into the report pipe and exits 127, and the parent, reading it, waits for the child and gives the errno; else the report pipe's end of file means exec happened, and the parent's end becomes the IO, kind 3 with the pid, which `kv_io_free` closes and waits for, setting status and signal as for a `popen`. `IO.exec` is read in the `IO.` branch: a `[` starts a list of text items, each a String's or Bytes's `.cstr` where it is one in a variable; else an Array of cstr or of String in a variable; then the mode; an E_CALL of op `io_exec`, text `list`, `cstrs` or `strings` |
| P103 | Details of #91 | `p.ok.kill(SIGTERM)` is `kv_io_kill((kv_io *)&(*_kv__kv_res_IO_i32_at_ok(&p)), SIGTERM)`, `out.pid` `kv_io_pid((kv_io *)&out)` | `kv_io_kill` is `kill` on the pid of an IO of kind 3 that is open, false otherwise; `kv_io_pid` that pid, or -1. `kill` is an IO method of one argument giving a `bool`, as `seek` is; `pid` an IO property typed `i32` |
| P104 | Details of #92 | `IO.exec(["pwd"], "r", "/")` is `kv_io_exec(&_kv_f, (const char *const[]){(const char *)("pwd"), NULL}, "r", "/", NULL)` inside the Result-making statement expression; an environment given as an Array of Strings `senv` adds `const char **_kv_env = kv_io_vector_strings((senv).at, (senv).count);` before the call, `(const char *const *)_kv_env` as its last argument and `kv_io_vector_free(_kv_env);` after it | `kv_io_exec` and its Array forms take `dir` and `env`: in the child, after the pipe is on its stdout or stdin, `chdir(dir)` when `dir` is not empty, then `putenv` of each entry, each failure reported through the close-on-exec pipe as exec's is. The parser reads the directory as text or a String's `.cstr` into the call's `a`, and the environment as a list, an E_INIT in `d`, or an Array in `d` with its type in `recv_type`, so that the codegen picks `kv_io_vector_cstrs` or `kv_io_vector_strings`. CI's Linux clang refused `putenv`, an X/Open function that glibc hides under `_POSIX_C_SOURCE` alone, which the runner's older gcc had let through as an implicit declaration: runtime/io.c now defines `_XOPEN_SOURCE 700`, POSIX 2008 and X/Open together |
| P105 | Details of #93 | `IO.exec(["env"], "r", "", ["ONLY=1"], true)` is `kv_io_exec(&_kv_f, (const char *const[]){(const char *)("env"), NULL}, "r", "", (const char *const[]){(const char *)("ONLY=1"), NULL}, true)` in the Result-making expression | `kv_io_exec` and its Array forms take `fresh`: in the child, `environ` is set to the entries' NULL-ended vector, or to an empty one, in place of `putenv`; `execvp` then searches that environment's PATH, or `_PATH_DEFPATH`. The parser reads the fifth argument, which `seen_bool` must see as a bool, into the call's `fresh`; the codegen writes it as a condition, or `false` |
| P106 | Details of #94 | `SYS.argv` is `_kv_array_cstr_from((const uint8_t *const *)kv_sys_argv_p(), (size_t)kv_sys_argc_n())`; `OS.listdir(dir)` is `({ kv_string *_kv_at = NULL; size_t _kv_n = 0; int _kv_e = kv_os_listdir(dir, &_kv_at, &_kv_n); _kv_array_String _kv_a = _kv_array_String_from(_kv_at, _kv_n); free(_kv_at); _kv_e ? ..._make_err(_kv_e) : ..._make_ok(_kv_a); })`; `OS.env(n)` wraps `kv_os_env(n)` into a `cstr?`; the rest `kv_os_<name>(...)` | `OS` and `SYS` are keywords, read in `parse_primary` before `.` through one table of members, each with its arity (-1 a property, also written with `()`) and what it gives, which picks the type: `i32`, `bool`, `cstr`, an Optional or a Result through `optional_type` and `variant_type`, or an Array through `array_type`, which registers it; text arguments take a String's or Bytes's `.cstr`, and a number is refused but for `exit`. The C `main` of a Kelvin `main` with no parameters is `int main(int _kv_argc, char **_kv_argv)`, and every `main` begins with `kv_sys_init(argc, argv)`, so `SYS.argv` is there with no declaration. runtime/os.c defines `_XOPEN_SOURCE 700` as io.c does |
| P107 | Details of #95 | `OS.lstat(p)` is `({ kv_stat _kv_st = {0}; int _kv_e = kv_os_lstat(p, &_kv_st); _kv_e ? ..._make_err(_kv_e) : ..._make_ok((struct _kv_anonN){.dev = _kv_st.dev, .ino = _kv_st.ino, ...}); })` | The member table now holds, per member, its arguments as letters (`t` text, `i` an integer, `f` a number) and what it gives, which picks the type and the codegen's shape: `res_string` for a `Result<String, i32>` filled through a pointer, `opt_cstr` for a `cstr?`, `string` for a String made and given, `stat` for the struct. The stat struct is an untagged struct `stat_type` registers, its members named and ordered as the prelude's `kv_stat`, which the runtime fills from `struct stat`; the codegen copies it member by member, by name, into the struct kelvinc wrote, so neither side depends on the other's layout. `makedirs` walks the path's parts with `mkdir`, `EEXIST` allowed; `time` is `timespec_get`; `sleep` is `nanosleep`, resumed after a signal |
| P108 | Details of #96 | `OS.walk(d)` is `({ kv_string *_kv_at = NULL; size_t _kv_n = 0; int _kv_e = kv_os_walk(d, &_kv_at, &_kv_n); _kv_array_String _kv_a = _kv_array_String_from(_kv_at, _kv_n); free(_kv_at); ... })`, as `listdir` is; `glob` the same with `kv_os_glob` | `kv_os_walk` lists each directory with `kv_os_listdir`, which sorts, joins each name to its directory with `kv_os_join`, pushes it, and goes into it when `lstat` says it is a directory, its failure passed over; `kv_os_glob` is `glob` with no flags, so sorted, `GLOB_NOMATCH` an empty result, `GLOB_NOSPACE` `ENOMEM`, else `EIO`. Both are table members giving `listdir`, whose codegen now calls `kv_os_<name>` |
| P109 | Details of #97 | `OS.mkstemp("k_")` is `({ struct _kv_anonN _kv_t = {0}; int _kv_e = kv_os_mkstemp("k_", &_kv_t.io, &_kv_t.path); _kv_e ? ..._make_err(_kv_e) : ..._make_ok(_kv_t); })`; `OS.mkdtemp("k_")` through the `res_string` shape | `temp_type` registers `{io: IO, path: String}` as `pipe_type` does; the runtime builds the template from `tmpdir`, the prefix and `XXXXXX`, calls `mkstemp` and `fdopen` with `"w+"`, or `mkdtemp`. macOS hides `mkdtemp` under `_XOPEN_SOURCE`, so runtime/os.c and io.c now define `_DARWIN_C_SOURCE` there and `_XOPEN_SOURCE 700` elsewhere, as kelvinc's own main.c does |
| P110 | Details of #98 | `OS.utime(p, 1.0, 2.5)` is `kv_os_utime(p, 1.0, 2.5)`, `OS.touch(p)` `kv_os_touch(p)` | `kv_os_utime` splits each `double` into a `timespec` and calls `utimensat(AT_FDCWD, ...)`; `kv_os_touch` opens the file with `O_CREAT` and closes it, then `utimensat` with `UTIME_NOW` for both. Table members with arguments `tff` and `t` giving `i32` |
| P111 | Details of #99 | `OS.chown(p, OS.uid, OS.gid)` is `kv_os_chown(p, kv_os_uid(), kv_os_gid())`; `OS.username(0)` is `({ kv_string _kv_s = {0}; kv_os_username(0, &_kv_s) ? ..._make_some(_kv_s) : ..._make_none(); })`, a `String?` | `kv_os_chown` and `kv_os_lchown` cast the ids to `uid_t` and `gid_t`, so -1 is C's leave-alone; `kv_os_username`, `kv_os_groupname` and now `kv_os_user` copy the name out of `getpwuid`'s and `getgrgid`'s static storage into a String, false where there is none: CI's Linux showed the name read for uid 0 as the runner's, since a later lookup had overwritten the storage a `cstr?` pointed into. Table members `tii` giving `i32`, and `i` giving `opt_string`, a new shape. With `OS.user` an owner, `OS.user.is(some)` in a test leaked its String, which `.is` of a value an expression gives always did for an owning record: `.is` and `.case` of such a value are now errors that say to bind it, as `.count` of an unbound Bytes is. A file made in a directory may take the directory's group, as on macOS, which the test allows for |
| P112 | Details of #100 | `IO.popen(cmd, "r")` is as before in the program's C; in the runtime, `kv_io_popen` calls `kv_io_exec` with `{"/bin/sh", "-c", cmd, NULL}`, no directory, no environment | `kv_io`'s kind 2, the `pclose` one, is gone: a process is kind 3, waited for by its pid in `kv_io_free`, whichever way it was started; `kv_io_kill` and `kv_io_pid` then serve both. A shell that is missing is `ENOENT`, as an `IO.exec` program is |
| P113 | Details of #101 | `f.path` is `kv_io_path((kv_io *)&f)`, `f.stat` the stat shape over `kv_io_stat`, `d.listdir` the listdir shape over `kv_io_listdir`, `f.rename(to)` `kv_io_rename((kv_io *)&f, to)`; `IO(p)` is `kv_io_open(&_kv_f, p, "r")` | `kv_io` gains `path`, a copy made by `kv_io_open` and `kv_os_mkstemp`, freed by `kv_io_free`, moved by `kv_io_take`, NULL for a stream, a descriptor or a process. The runtime's `kv_io_*` path functions call `kv_os_*` on it, or `fstat`, `fchmod`, `fchown` and `ftruncate` on `fileno` where the file is open, `ENOENT` where there is no path. In the parser, the IO property list gains the names with their types, and the method table the methods, their arguments checked by kind as `OS`'s are through a small table; `rename` is `changes`, so a let refuses it; `value_type` of an IO method is its type for these names alone, since every owner method carries its receiver's type for the codegen, which made `f.write(...)` as a statement look like a dropped owner when all were typed. The codegen reuses the `res_string`, `listdir` and `stat` shapes of `OS` with `kv_io_` calls |
| P114 | Details of #102 | `OS.uname` is `({ kv_uname _kv_st = {0}; int _kv_e = kv_os_uname(&_kv_st); _kv_e ? ..._make_err(_kv_e) : ..._make_ok((struct _kv_anonN){.sysname = _kv_st.sysname, ...}); })`, the stat shape made general: the runtime's `kv_<gives>` copied by name; `OS.groups` the listdir shape over `int32_t`; `OS.urandom(n)` a Bytes filled through a pointer | `anon_struct(at, spec)` makes an untagged struct from its spelling, `"root: String, ext: String"`, and `struct_spec(gives)` holds the spellings of `stat`, `uname`, `splitext`, `loadavg`, `terminalsize` and `diskusage`, so the parser types a member and the codegen copies its C struct, named `kv_<gives>`, by the same names; `pipe_type`, `temp_type` and `stat_type` now go through it. `normpath` and `relpath` work on the text, as Python's do, `relpath` making both paths absolute with `cwd` first; `expanduser` reads `HOME`, else `getpwuid`, and `getpwnam` for `~user`; `urandom` reads `/dev/urandom`; `terminalsize` is `ioctl(1, TIOCGWINSZ)`; `diskusage` is `statvfs` in `f_frsize` units. runtime/os.c includes `sys/ioctl.h`, `sys/statvfs.h` and `sys/utsname.h`, and on glibc defines `_DEFAULT_SOURCE` beside `_XOPEN_SOURCE`, since CI's Linux clang found `getloadavg`, a BSD extension, declared only for that |
| P115 | Details of #103 | `out.isatty` is `kv_io_isatty((kv_io *)&out)`; `IO.strerror(e)` is `kv_os_strerror(e)`, the very node `OS.strerror` makes | `kv_io_isatty` is `isatty(fileno(fp))`, false with no FILE; `isatty` joins the IO property list as a `bool`. `IO.strerror` is read in the `IO.` branch into an E_CALL of op `os` and text `strerror`, so the codegen of `OS` serves it; the argument must be an integer, or a name only C sees |
| P116 | Details of #104 | `f.stat` is `({ kv_stat _kv_st = kv_io_stat((kv_io *)&f); (struct _kv_anonN){.dev = _kv_st.dev, ...}; })`, the OS struct shape without the Result; `f.abspath` is `kv_io_abspath((kv_io *)&f)`, a `kv_string` | `kv_io_stat` gives the struct by value: fstat of the stream, else the path's stat once closed, else all zero; `kv_io_lstat` is lstat of the path, else `kv_io_stat`; `kv_io_isdir` and `kv_io_isfile` read `kv_io_stat`; `kv_io_abspath` is realpath of the path, else `""`. Found while testing: `f.stat.size` gave sizeof, since `expr_class` classed every property that is no integer as "n"; a property typed as a struct kelvinc sees now classes as that struct, so its fields win over `.size` and the rest, as a variable's do. `try f.stat` is an error, as of any non-variant |
| P117 | Details of #105 | `f.abspath` is still `kv_io_abspath((kv_io *)&f)` | `kv_io_abspath` tries `kv_os_realpath` of the path, then `fcntl(F_GETPATH)` on Apple or `readlink` of `/proc/self/fd/<fd>` on Linux into a `PATH_MAX` buffer, cutting a trailing ` (deleted)`, and gives the answer only when it starts with `/`; `""` otherwise. The tests that read `IO.stdout.abspath` now read a pipe end's, since the runner sends stdout to a file, which `F_GETPATH` names |
| P118 | Details of #106 | `d.listdir` is `({ kv_string *_kv_at = NULL; size_t _kv_n = 0; kv_io_listdir((kv_io *)&d, &_kv_at, &_kv_n); _kv_arr_String _kv_a = _kv_arr_String_from(_kv_at, _kv_n); free(_kv_at); _kv_a; })`, the Result's two makers gone; `d.glob(p)` the same through `kv_io_glob` | `kv_io_listdir`, `kv_io_walk` and `kv_io_glob` give void and fill the array, empty on any failure; `dir_of` in runtime/io.c picks the path when `stat` answers, else `kv_io_abspath`. The method table's `gives` "listdir" now means an Array; `OS`'s "listdir" shape stays a Result. `for p in d.walk { }` is refused as any owner an expression gives: bind it |
| P119 | Details of #107 | `f.string` is `kv_io_read_string((kv_io *)&f)`, `f.bytes` is `kv_io_read_all((kv_io *)&f)`, each by value | `kv_io_read_all` reads until `fread` gives nothing, clears `ferror`, and gives the Bytes, empty of a closed IO; `kv_io_read_string` checks UTF-8 and calls `kv_io_fail` with "the rest of the file read by .string is not UTF-8: read .bytes, or walk .read(n)". io_basics's `bad_text` now gives `b.isUTF8` of the bytes, false, where it gave `err(EILSEQ)` |
| P120 | Details of #108 | `f.chmod(m)` is `kv_io_chmod((kv_io *)&f, m)`, a `bool`, as before but for the type | The method table's `gives` "i32" became "bool" for the seven, with `is_bool` set as for `seek`; the runtime's seven give `bool`; `kv_os_futime(fd, a, m)` and `kv_os_ftouch(fd)` join os.c beside `kv_os_utime` and `kv_os_touch`, since `at_seconds` lives there; `name_of` (was `dir_of`) serves remove and rename too. Of a removed file, `f.remove()` again is false, since the descriptor's name is gone, while `f.truncate(0)` is true: the file is open |
| P121 | Details of #109 | `IO(p, m)` is `kv_io_open(p, m)` by value, `IO(fd, m)` is `kv_io_fdopen(fd, m)`; `f.error` is `kv_io_error((kv_io *)&f)` | `kv_io` gains `int error`; `kv_io_open` keeps the path and sets `error` when `fopen` fails, with no stream, so every reader's `!f->fp` branch serves; `open_fp`, which ends the program on a closed IO, now says `<path>: <strerror> (reading an IO that did not open; ask f.error first)` when `error` is set. `IO.popen` keeps the old `({ kv_io _kv_f ... })` shape. The tests that read `if let ok(f) = r` now read `if f.error == 0`, and the error tests about `let` bind the IO with `let` directly |
| P122 | Details of #110 | `IO.popen(c, m)` is `kv_io_popen(c, m)` by value; `IO.exec(...)` is `kv_io_exec(argv, m, dir, env, fresh)`, or `({ const char **_kv_env = ...; kv_io _kv_f = kv_io_exec(...); kv_io_vector_free(_kv_env); _kv_f; })` with an Array's environment; `IO.pipe()` is `({ struct _kv_anonN _kv_p = {0}; kv_io_pipe(&_kv_p.reader, &_kv_p.writer); _kv_p; })` | The fork and exec body is now the static `exec_into`, and `process_of` puts its errno into `.error`; `kv_io_pipe` gives void and sets both ends' `.error`. The tests read `if p.error == 0` for `if p.is(ok)`, and the pair's members directly for `ends.ok.reader` |
| P123 | Details of #111 | `point.of(3, 4)` is `point__of__i64__i64(3, 4)`; a lone `point.origin()` is `point__origin()` | `parse_method` takes the `static` storage as the mark, makes a D_FN named `T.name` with `type_fn` and `recv_name` set and no `recv`, and parses the rest through `parse_fn_tail`, which `parse_fn` now shares; `name_functions` writes `T__name` for the C name, with the types appended by the usual rule, so an imported module's are always by types. At a call, `T.name` where `T` is a record and `name` is no case and `function_named("T.name")` holds is read as the identifier `T.name`, with its overloads, and the call goes the way of any function's. The method-name scan of the tokens skips `static let T.name(`, so `v.name()` is no method call, and says to use the type's name |
| P124 | Details of #112 | `#import <JSON>` reads `modules/JSON.k` | The lexer counts a header name with no `.` as a Kelvin file; `import_path` appends `.k`; the message of a missing file names both |
| P125 | Details of #113 | `JSON.parse(s)` is `JSON__parse__cstr(s)`, `JSON.stringify(&j, "  ")` is `JSON__stringify__const_JSONp__cstr(&j, "  ")`; the module's helpers are `static let JSON_...` functions, C-static | A recursive descent reader over a `JSONReader {at, i, count, depth}`; strings are gathered as Bytes, checked as UTF-8, then made Strings; `f64(bytes)` reads a number the grammar accepted. Found while writing it: a `return v` inside a branch marks `v` moved for the lines after it, so loops end with one return; an anonymous function with a `JSON?` result cannot be written inline, since `):JSON? in` reads the `?` as a conditional (a wart to fix); passing a JSON by value where a borrow is wanted says "an owner cannot be given to a C function", a message that should name the overloads instead; `.hex` of an integer gives `+0x..`, so messages do not show the code unit |
| P126 | Details of #114 | `{ (v:i64):i64? in none }` is a `static inline` function returning `_kv__kv_opt_i64_make_none()` | `type_shape_end`'s base-word loop ends in `type_suffix_end`, which takes `?` when a line break, a non-operand or `in` follows; `implicit_return` applies `optional_of` to the one expression, as `return` does. Still not wrapped: `none` as one arm of a `?:`, `c ? Optional<i64>(v) : none`, whose arms are typed before the result is known; write `if` and `return` |
| P127 | Details of #115 | `"""a "b"\nc"""` is the C literal `"a \"b\"\nc"` | `lex_triple` in the lexer, after `lex_template`'s model: a new line is `\n`, a backslash, a quote and a `?` are escaped for C, everything else is copied; the token is a plain TK_STRING, so `.count`, joining, `$` and `Bytes(...)` need nothing |
| P128 | Details of #116 | `c ? v : none` of an `i64?` is `c ? _kv__kv_opt_i64_make_some(v) : _kv__kv_opt_i64_make_none()` | `optional_of` distributes over an E_TERNARY that is no `??`; `parse_conditional` wraps the arm beside a variant with `optional_of`; `annotation_ahead` refuses a base word followed by `<` or `(` while a ternary's middle arm is parsed, where `ident_annotation_ok` is false |
| P129 | Details of #117 | `j["name"]` is `_kv_dict_String_JSON_at(&(*_kv_JSON_at_object(&j)), "name")`, the case read and the entry read, each checked; `j["tags"][0] = v` is `_kv_JSON_assign(_kv_array_JSON_at(...), v)` | In the index parse, after `]`, a receiver whose type is a tagged record is replaced by the E_FIELD of its first Dictionary case for text (a literal, a cstr, a String or a Bytes) or its first Array case otherwise, and the parse goes on as for that case; a slice takes the Array case. An enum with no such case, or with the other one only, is an error that says which it has. `_kv_T_assign(T *p, T v)`, free then store, is now written beside `_kv_T_free` for an enum with values and for a struct that owns |
| P130 | Details of #118 | a `"""` on its own lines is one C string literal of the lines between, each ended by `\n` but the last | `lex_triple` counts the opening run, gathers the raw text up to a run as long, keeping the extra quotes of a longer run, then takes off a first `\n`, a last `\n` and the blanks after it, which it strips from the start of every line that begins with them, and escapes the rest for C. A text that is only the two delimiter lines is `""`. An unterminated one says how many quotes it ends with |
| P131 | Details of #119 | `case some(v):` is `case 1: { __attribute__((unused)) const int64_t v = a.u.some; ... break; }`; of a call, `{ __auto_type _kv_switch_sw = half(10); switch (_kv_switch_sw.tag) { ... } }` | `parse_case_label` takes `(name)` after a case name, declares it with `LET_EACH`, the kind of a loop's element, and keeps it in the S_CASE's `name2` and `type`; the block emitter writes the let after the `{` it already opens for each case; the S_SWITCH emitter hoists a subject that is no C lvalue when any case binds. Moving the bound value out gets the message of a value a container still owns |
| P132 | Details of #120 | `rgb({1, 2, 3})` is `_kv__kv_anon1_make_rgb((struct _kv_anon1_rgb){1, 2, 3})` or the like, the maker of the spelling's record, as `T.n(x)`'s is | `parse_record` sees `enum {` with a `:` inside and reads it through `parse_anon_record`, the type-position path, so the record is the one of its spelling, registered once; the record joins `anon_words`, and the top-level loop gets NULL, since the record is in the program's declarations already. In `parse_primary`, an identifier that is no binding, no function and not followed by `.` is looked up in `anon_words`, and `case_maker`, split out of the `T.n(x)` block, makes the value. The clashes are checked where the enum is declared and where a function or an enumerator is |
| P133 | Details of #121 | `let enum{nothing, just: i64}.orZero()` is the C function `_kv_anon1__orZero(struct _kv_anon1 self)`, dispatched as any method by `_Generic` on `struct _kv_anon1` | `spelled_receiver(i)` finds `enum{...}`, `union{...}`, `struct{...}` or `{...}` followed by `.name(`; `function_shape` gives it shape 5, the top-level loop routes it to `parse_method`, which reads the receiver with `parse_type`, so the record is the one of its spelling, and names it in C by the record, `_kv_anonN`; the method-name scan takes `} . name (` at depth 0. In the binary path, an enum with values and an overloadable operator other than `==` and `!=`, or one of those when `user_operator_on` finds a definition taking the type, goes to `resolve_operator`; with none written, the old message stays, with "or define one" for an enum of the program. Printing such a value by itself with `println(v)` was still a C error, as it was for any struct, until #122 |
| P134 | Details of #122 | `println(p)` is `println(_kv_point_cstr(p, _kv_p_text))`, the C that `println(p.cstr)` gives | `print_records_as_text`, called by `check_print_args` for `print` and `println` and by the `f.print`/`f.println` branch of the member path, replaces each argument whose `expr_class` is `'s'` with `property(x, "cstr")`, as `parse_template` does for `${x}`; the text's buffer is the one `.cstr` makes in the enclosing block |
| P135 | Details of #123 | `println(xs)` is `println(({ __auto_type _kv_sv = (xs); _kv_show__kv_array_i64(&(kv_out){.fp = NULL}, &_kv_sv, -1); (const uint8_t *)""; }))`: the printer streams, and the argument prints as an empty text | In the parser, `print_records_as_text` (of #122) now wraps every argument that is a record kelvinc sees, an Array, a Dictionary or a Set in an E_PROPERTY `show`; an owner an expression gives is refused there. In codegen, a pre-pass collects the types, closed over members, elements, keys and case values; each gets `static void _kv_show_<key>(kv_out *, const void *, int)` declared after the includes, since it takes `const void *`, and written after everything; `level < 0` is one line. The runtime's `kv_out` writes to a stream (stdout for NULL) or appends to a String; `kv_out_quoted` escapes in full, and `kv_cstr_quoted_*` escape within `.cstr`'s room, cutting with `..."` outside a codepoint. `f.println` sets the sink to `kv_io_fp`. The refusal of `print(xs)` in `reject_owners_to_c` became unreachable and was removed; `${xs}` in a template still errors, now naming `print` and `.pretty` |
| P136 | Details of #124 | `cfg.pretty` elsewhere is `({ kv_string _kv_ps = kv_string_new(); ...; _kv_show_scene(&(kv_out){.s = &_kv_ps}, &_kv_sv, 0); _kv_ps; })` | `.pretty` is an E_PROPERTY `pretty` typed `String`, with the receiver's type kept; in a print call it turns into `show` at level 0. `kv_out_sep` writes `,` and a line at level + 1, `kv_out_end` a line at the level, before the closing bracket. A field named `pretty` wins, as fields do; `.pretty` of anything else is an error naming `.cstr` |
| P137 | Details of #125 | `` `${xs}` `` is `kv_string v = kv_string_new(); { __auto_type _kv_sv = (xs); _kv_show__kv_array_i64(&(kv_out){.s = &v}, &_kv_sv, -1); } KV_TEMPLATE_VALUE(build, KV_TEMPLATE_STR, v); kv_string_free(&v);` inside the template's statement expression; `` $`${xs}` `` appends with the printer straight into the String being built | In `parse_template`, a value that is an Array, a Dictionary or a Set becomes an E_PROPERTY `tpl_show` typed `String`, so its room is `KV_TEMPLATE_STR`; `` $`...` `` turns it into a `tplstr_show` part. The refusal of #123 is gone, and so is its error test; an owner an expression gives is refused, as `print` refuses it |
| P138 | Details of #126 | `` `${d.pretty}` `` is #125's code with the printer's level 0 | In `parse_template`, a `.pretty` value, an E_PROPERTY `pretty`, becomes `tpl_show`, keeping its text "pretty"; `` $`...` `` keeps that text on its `tplstr_show` part; codegen passes level 0 for it, -1 otherwise. The String a `.pretty` made in a template was never freed before |
| P139 | Details of #127 | `d.pretty(4)` is #124's code with `.width = 4` in the sink; a computed `w` is `.width = kv_out_width(w)`; plain `.pretty` is `.width = 2` | `kv_out` gains `int width`, which `out_line` writes as that many spaces a level; `kv_out_width` clamps to 0 to 10. The parser takes `.pretty(` ahead of the owners' method tables, which would refuse a method of that name, keeps the width as the node's `b`, and carries it through `print`, `f.println`, both kinds of template and the String form. Tests that pin a printer's C now show `.width = 2` |
| P140 | Details of #128 | `t += txt.s($"cd")` of an owning `txt` is `_kv_txt_assign(&t, _kv_add_op__txt__txt(_kv_txt_take(&t), ...))`, where it was `_kv_txt_free(&t), t = _kv_add_op__txt__txt(_kv_txt_take(&t), ...)` | `owner_assign` in codegen sends a local owner whose free is a record's to `_kv_T_assign`, written for every struct or enum with values that owns since #117, instead of freeing first; Bytes, Strings, Arrays, Dictionaries and Sets already went through their own `_assign` |
| P141 | Details of #129 | `JSON.stringify(&j, 4)` is `JSON__stringify__const_JSONp__i64(&j, 4)` | `JSON_spaces(n)` in modules/JSON.k gives the tail of a literal of ten spaces, `n` of them, clamped to 0 to 10, and the two overloads pass it to the text path, so a number and the same spaces as text give the same output |
| P142 | Details of #130 | `extend rect { let f() {} }` is `let rect.f() {}`, the same Decl | `parse_extend` sets `in_extend`, `ext_tok` and `ext_spelled`, and each member goes to the parser of its alone form, which then reads no receiver: `parse_method` for `let f(`, `static let f(` and `let x:`, `parse_var_attribute` for `var x:`, `parse_type_attribute` for `static let/var x`. The method-name prescan also takes `let f(` at the top of an extend body, so `v.f()` is a method call. An operator in extend is an error |
| P143 | Details of #131 | `r.area` is the E_METHOD of `r.area()`, marked `attr`, so it dispatches as any method, to `rect__area(r)` | `function_shape` gives 6 for `T.x:` and `T.x =`, and `spelled_receiver` takes `.x:` too; in `parse_method`, a `:` where `(` would be makes the Decl an `attribute` with no parameters, which needs a body. The member parse reads `v.x` as the getter where `method_named` finds an attribute, before properties and after a field |
| P144 | Details of #132 | `t.celsius = v` is `temp__set_celsius(&(t), v)`; the setter is `void temp__set_celsius(struct temp *_kv_selfp, double v)` with `#define self (*_kv_selfp)` around its body | `parse_var_attribute` makes two Decls, the getter and a `setter` with the parameter of `set(v)`; `method_named` and dispatch skip setters, and the C-name check names them `T__set_x`. `parse_assign` turns `v.x op= y` into an E_CALL `attr_set` before the usual checks: the receiver must be a var place, and a compound one is read twice, so it may not hold a call |
| P145 | Details of #133 | `static var rect.made:i64 = 0` is the global `int64_t rect__made = 0;`, and `rect.made` is the identifier `rect__made` | `parse_type_attribute` parses the declaration as `parse_var` does, then renames the Var and its binding to `T__x` and lists it in `type_attrs`; the primary expression reads `T.x` as that identifier where `T` is a record, after its cases and functions |
| P146 | Details of #134 | `p.name = $"Grace"` is `kv_string_assign(&(p.name), KV_STRING_OF("Grace"))`, where it was `p.name = KV_STRING_OF("Grace")` | `parse_assign` marks an `=` to a place other than a name, of an owner other than an IO, with the place's type, and `owner_assign` writes the type's `_assign` for it |
| P147 | Details of #135 | `static let +(a:money, b:money):money` in `extend money` is `_kv_add_op__money__money`, as `let +` at the top level is | `parse_extend` takes `static` `let` and an overloadable operator before `(` to `parse_fn`, the top level's parser of operators, then checks a parameter's type against the receiver's from `attribute_receiver`; without `static`, or another punctuation, it is an error |
| P148 | Details of #136 | `g[1, 2]` is `grid__subscript__i64__i64(&(g), 1, 2)` and `g[1, 2] = 7` is `grid__subscript_set(&(g), 1, 2, 7)`; a receiver that is no place is a temporary first. The getter takes `const T^`, the setter `T^`, each named `_kv_selfp` with `#define self (*_kv_selfp)` around the body | `function_shape` gives 7 for `T[](`, and `parse_extend` sends `let [` and `var [` to `parse_subscript`, which makes the Decls `T.[]` and `T.[]=`, functions of the type marked `subscript`. The index parse chooses an overload by the count of indices, then their types, a literal as the type it infers to before any of its kind, before #117's cases; `parse_assign` turns `v[i] op= y` into an E_CALL `subscript_set` with the setter of the same index types |
| P149 | Details of #137 | `let counter.sum:i64 { ... }` is `int64_t counter__sum(const struct counter self)`, so `&self` is a `const struct counter *` and C warns where it is passed to a `counter^`, as of any let parameter | `parse_method` binds `self` with LET_PARAM when it reads a `:` after the name, and `attribute_body` does for a getter, not a setter; `let_target`'s error for `self` in a getter names the setter; `fn_head` writes a getter's receiver with `const` |
| P150 | Details of #138 | `let point.moved(dx:i64):point` is `struct point point__moved(const struct point self, const int64_t dx)` | `parse_method` binds `self` with LET_PARAM for every method; `let_target`'s error for `self` in a method names a setter and `T^`; `fn_head` writes every receiver but a setter's with `const`. tests/run/let_var.k, tag_names.k and examples/shapes.k change a `var` copy now |
| P151 | Details of #139 | `.w * .h` is `self.w * self.h` | `parse_primary` reads `.` and a member's name as the identifier `self` where `self` is bound, and leaves `.x` to the postfix; with no self, in a function, it is an error that says so, and of the function around an anonymous one, the error of #32. An initializer's `.` is a designator where `designator_ahead` finds `=` after the chain, or outside a function. `self_statement_at` ends an expression before a new line's `.x`, `.x.y` or `.x[i]` followed by an assignment, `++` or `--`, both in `line_ends_expression` and in `statement_ends_at` |
| P152 | Details of #140 | `let moved(dx:i64):Self` in `extend point` is `struct point point__moved(const struct point self, const int64_t dx)`, as with `point` written | `rewrite_self` turns each token `Self` into `T`'s over the extend block, from its `{` to the matching `}`, or over a member written alone, to the `}` of its body, a `;`, or a new line that starts a statement, so every lookahead that tells a type from an expression sees `T`. `self_scope`, `self_tok` and `self_spelled` are set by `parse_extend` and the member parsers; outside them `self_word` makes `Self` an error, and for a type with no tag `parse_type_in` reads `Self` as the spelling while an expression's `Self` is an error |
| P153 | Details of #141 | `let greet(name:cstr):()` is `void greet(const uint8_t *const name)`, as without `:()` | `void_result_ahead` sees `(` `)` not followed by `:` after the result's `:`, in `parse_fn_tail`, `parse_method_of`, `parse_anon_fn` and `parse_fn_type`, and leaves the result NULL, which was void already |
| P154 | Details of #142 | `let k = 10` then `.is(just) ? ...` on the next line in a method is two statements, where it was `10.is(just)`; `let k = (.xs` then `.count)` is `self.xs.count` | `self_statement_at` is true for any `.member` on a new line at the top of a statement where `self` is bound, not only one followed by an assignment; `line_ends_expression` and `statement_ends_at` ask it, as before |
| P155 | Details of #143 | `#import <IO>` becomes the tokens of `modules/IO.kh`, and `cc ... ./modules/libkIO.a ./modules/libkOS.a .../libkelvin.a -lm` | `import_path` tries `M.kh` before `M.k` for a bare name, and the lexer reads `<M.kh>` as a Kelvin file; `module_library` records `libkM.a` beside the header, or `-lkM` for a shared one, as each `.kh` is first brought in, and the driver links them before `libkelvin`. The parser lists each imported module's name from its `#import` token, which `prog->modules` hands the codegen |
| P156 | Details of #144 | `kelvin_prelude.h` ends at the String functions; `kIO.h` holds the `kv_io` struct and the `kv_io_*` prototypes, `#include "kOS.h"` for `kv_stat`, and `IO.kh` is `#import <OS>` and `#import <kIO.h> as C` | `require_module("IO")` at `IO(`, `IO.`, the type `IO` and `extend IO`; the Makefile builds `libkIO.a` and `libkIO.dylib|.so` from io.o, the shared one linked against libkOS and libkelvin |
| P157 | Details of #145 | `kOS.h` holds `kv_sys_*`, `kv_os_*`, `kv_stat` and the structs of #102, with `struct kv_io;` forward for `kv_os_mkstemp`; a `main` calls `kv_sys_init(argc, argv)` only where OS is imported | `require_module("OS")` at `OS.`, and `SYS.` checks the same module with its own message; os.c includes kIO.h for the IO it fills. tests/run.sh builds `libkshout.a` for tests/project's `shout.kh`, and compiles a program importing IO from the installed layout, checking the libraries it links |
| P158 | Details of #146 | `let norm1:f64` in geo.kh declares `double point__norm1(const struct point self);`, which libkgeo.a defines; `static let of(x:f64, y:f64):Self` is `point__of__f64__f64` on both sides | `gen_header` walks the main file's tokens and copies the raw source text of each declaration up to its body, found by `header_end`, which skips a `{` after `:` or a type word as a type; `kelvin_proto` marks a bodiless function in a `.kh` that is not `extern`, and `name_functions` counts it as defined, so the program names it by its types as the library does, whose tokens `--lib` marks imported; `parse_method_of`, `parse_var_attribute` and `parse_subscript` take a prototype in a `.kh`; the driver compiles with `-c -fPIC`, drops the libraries and `-L`, and runs `ar rcs` |
| P159 | Details of #147 | `libkgeo.dylib` with `@rpath/libkgeo.dylib` as its install name, depending on `@rpath/libkelvin.dylib` | `link_shared` runs `cc -dynamiclib -install_name @rpath/libkM.dylib` (or `-shared -Wl,-soname`) on the object, with `-L./modules`, `-L` of Kelvin's `modules/`, each library of `module_libs` and `libkelvin` taken as its shared sibling where one exists, and `-lm`; tests/run.sh links tests/project/geo_c.c against `libkgeo.$so` by its path, with rpaths, and runs it |
| P160 | Details of #148 | `f64.pi` is the global `const double f64__pi = 3.141592653589793;`, `x.sin()` dispatches by `_Generic` to `f64__sin`, `f32__sin`, `complex64__sin` or `complex32__sin`, and `1.0.i` to `f64__i`, giving a `struct complex64` | `parse_type_attribute` takes a converter word as the receiver, and the primary reads `f64.pi` as a type attribute where one is declared; `method_named` and `value_type` give a literal receiver its own type through `arg_type`, so `1.0.i` and `(-1.0).i` are typed; `gen_header` writes a type attribute as `static let x:R` in its block, which `parse_type_attribute` reads in a `.kh` as extern, and moves past the initializer. A method has one form per name, so `z.pow` takes a `Self` only. `z.i` is `Self(0.0 - .imag, .real)`, so that no zero turns negative |
| P161 | Details of #149 | `typealias pt = point` then `let p:pt` is `struct point p`, and `pt.of(1, 2)` is `point__of__i64__i64(1, 2)` | `parse_typealias` checks the names and rewrites every later token spelled `A` to `T`'s text and kind, as `rewrite_self` does for `Self`, so every reading of a name sees `T`; `gen_header` copies the line as written |
| P162 | Details of #150 | `complex64__f64__f64` is `c64__f64__f64` in C, and `_kv_show_c64` prints one | the structs, converters, operators, functions and methods of math.k are named `c64` and `c32`, with the two `typealias` lines after the structs; the tests, examples and documents say `c64`, but tests/run/complex.k, which spells `complex64` throughout to try the alias |
| P163 | Details of #151 | `var n:int64` is `int64_t n`, as `var n:i64` is | the lexer gives a token spelled `int64` the text `i64` and the keyword kind, from a table of the twelve names, so that the parser and messages see the short name |
| P164 | Details of #152 | `["a":1,0:nil]` is `SION.dictionary` of four values, `string("a")`, `integer(1)`, `integer(0)`, `nil`; `s["a"]` is `SION__subscript__cstr(&s, "a")`, a copy | modules/SION.k follows JSON.k: a reader struct and functions of the type; a collection is a dictionary where `:` follows its first value; a moved owner that a second branch would take is assigned anew in the first, since the move check is flow-insensitive; `SION.same` compares member by member, and the subscripts copy and copy in, since a setter's value is a borrow |
| P165 | Details of #153 | `MsgPack.pack` of `.Date(1.5)` is `d7 ff 77 35 94 00 00 00 00 01`, the nanoseconds shifted 34 over the seconds | modules/MsgPack.k: `struct MsgPack { packed: Bytes }` is the functions' name only; a double's bits go through `memcpy`; counts take the fix byte, else the 8-, 16- or 32-bit code of the kind; signed ints are sign-extended by a shift; an ext's reader starts from its format byte so that the ext keeps its whole encoding |
| P166 | Details of #154 | `println(s["a"].integer)` compiled and leaked the copy `s["a"]` gives; now it is the error `.is` gives | the checks of `.is` and `.case` in the member parse, `is_owner(value_type(e)) && !owner_place(e)`, now guard the read of a case's value and of an attribute too; ASan on the SION tests showed the leak |
| P167 | Details of #155 | `b.toBase64(url)` is `kv_bytes_base64(&b, true, true)`, and `Bytes.fromBase64(&s)` reads the String's bytes through `kv_bytes_from_base64(p, n)` | runtime/bytes.c holds the two, declared by kelvin_prelude.h; the parser lists `toBase64` among a Bytes's methods, reading its arguments as the two words, and reads `Bytes.fromBase64(` before the converters, taking text or `&s`; a String place without `&` is an error that says to borrow it |
| P168 | Details of #156 | `#import <UnicodeData>` reads `modules/UnicodeData.kh`, which `make` builds by `./kelvinc --lib modules/UnicodeData.k build/runtime/unicode_*.o -o modules` | `--lib` takes `.o` and `.a` files after the source and archives them into `libkM.a` and links them into the shared one; the C API is `ucd_*`, since `kv_` names are reserved in Kelvin source; the parser lets a method of the program on a String or a Bytes win over the built-in table, and `.utf32`, `.codepoint` and `.capacity` are not buffer text in an attribute's body; the enum `NormalForm` is C's, as a top-level enum of bare cases; a long table literal is compiled with `-Wno-overlength-strings` |
| P169 | Details of #157 | `$/a+/g` is `RegExp.compile("a+", "g")`, a `RegExp{program, source, flags}` whose program `rx_compile` makes in a Bytes; `s.match(&re)` loops `rx_search`, which fills 2 × (groups + 1) byte offsets, and a `Match` holds the texts, the codepoint offsets and the names | The program is words: a header, the code (CHAR, ANY, CLASS, SPLIT, JMP, SAVE, BOL, EOL, WORDB, BACKREF, LOOK, MATCH, GRAPHEME, RESET, MARK, CHECK), the class data and the names; a counted quantifier is unrolled, a loop's empty iteration ends it (MARK, CHECK), and the groups in a repeated group are reset each time; the `i` flag folds by `ucd_to_fold`, and a class under it tries the fold, the upper and the lower case too; the modifiers `(?ims-ims:)` set the flags per node, written into the instructions; `\p{...}` looks names up in `kv_ud_gc_names`, `kv_ud_script_names` and `kv_ud_props`; a pattern that is not one aborts the program with its position; `rx_alloc` uses malloc, so that the counting build sees it |
| P170 | Details of #158 | `b.add(1)` with two `add` methods calls `box__add__i64`, `b.add() { $0 * 10 }` the one whose parameter is a function; `s.replace(&re) { ... }` is `String__replace__constRegExpPtr__...`, named by its types | `method_candidates` lists the methods of the name on the receiver's type, one per signature; `method_param_type` gives an anonymous argument the type of the only candidate with a function there; `choose` picks, and the call keeps the method in `Expr.method`, by which the codegen calls it directly where it has a types name, with `_kv_T_take` of a local owner argument, as a function call has; `dispatch` lists one C function per receiver type for the `_Generic` of unresolved calls; a call through a function value keeps its type in `Expr.fn_type` for the same takes; `kv_string_i64`, `_u64`, `_f32`, `_f64` and `_bool` are `KV_STRING_OF`'s cases |
| P171 | Details of #159 | `s.match(&re) { f }` is `String__match__constRegExpPtr__...(s, &re, f)`, which calls `RegExp.match(&s, f)`: `rx_search` from each match's end, an empty match moving on by one codepoint, and `f(Self.matchAt(&self, s, caps))`, the Match moved into f | the same walk as the Array form's and `replace`'s, with nothing kept |
| P172 | Details of #160 | `s.split(&re) { f }` calls `RegExp.split(&s, f)`: JS's split, sticky searches from each position, an empty match between codepoints skipped where it would cut nothing, and `f(rx_slice(s, piece, at))` for each piece, the String moved into f | the same walk as the Array form's, with nothing kept |
| P173 | Details of #161 | `s.replace(&re, &t)` is the `cstr` form on `t.cstr`, an overload by #158 whose parameter is `const String^` | the Array, `match` and `split` forms have no text argument, so nothing else changes |
| P174 | Details of #162 | `RegExp("a+", "g")` is `RegExp__cstr__cstr`, and `RegExp(&p, &f)` `RegExp__constStringPtr__constStringPtr`, by their types; each calls `RegExp.compile` | the parser reads `T.name(...)` and `T.x` where `T` is a record also where a function of its name is bound, which a variable of its name still hides |
| P175 | Details of #163 | the lexer calls `rx_check(pattern, flags, &at)` of runtime/regexp_parse.c, linked into kelvinc with runtime/unicode_tables.o, and reports its message at the literal's column plus 2 plus `at` | runtime/regexp_internal.h holds the tree, the parser's state and the helpers the two files share; `rx_parse_pattern` reads the flags and the pattern for both `rx_compile` and `rx_check`; the `\p{...}` names are looked up in the tables directly, so that nothing of libkelvin is linked into kelvinc; libkRegExp holds both objects |
| P176 | Details of #164 | `s.escape()` is `kv_string_escape(&s)`, `s.unescape()` `kv_string_unescape(&s)`, in runtime/string.c; `s.escape(&re)` is `rx_escape(&re.program, &s)` of libkRegExp, every match from each end, an empty one moving on by a codepoint | the parser lists `escape` and `unescape` among a String's methods, and takes the built-in one for a call with no argument where `method_takes_none` finds no method of the program without parameters; the hex of `\u{...}` is upper case with no padding |
| P177 | Details of #165 | `s.unescape(&re)` is `rx_unescape(&re.program, &s)`: every match from each end, the text between copied, each match sliced and read by `kv_string_unescape` | an escape cut by a match's end stays as written, as it would alone |
| P178 | Details of #166 | `b.escape()` is `kv_bytes_escape(&b)` in runtime/bytes.c, listed among a Bytes's methods in the parser, which types it as a String | the bytes 0x20 to 0x7E but `\` are themselves |
| P179 | Details of #167 | `Bytes.unescape(text)` is `kv_bytes_unescape_text(text)`, and `Bytes.unescape(&s)` `kv_bytes_unescape(p, n)` of the String's bytes, as `Bytes.fromBase64` is read, by the one parser path for both | runtime/bytes.c reads the escapes over bytes, with its own UTF-8 writer, so that a String is not needed |
| P180 | Details of #168 | `b.escape(&re)` is `rx_escape_bytes(&re.program, &b)`, over `rx_search_bytes`, the matcher's Ctx with `bytewise` set, where `cp_here` and `cp_prev` read a byte, `\X` is a byte, and a first character above 255 matches nothing; `Bytes.unescape(&s, &re)` is `rx_unescape_bytes(&re.program, p, n)`, the text matched as text and each match read by `kv_bytes_unescape` | the parser reads `Bytes.name(` and `String.name(` as a function of the type where the program declares one and the call is not the one-argument `Bytes.fromBase64` or `Bytes.unescape`, counting the arguments ahead; an attribute found by name alone is dropped where the receiver's type is seen and is not its; `gen_header` keeps one list of seen prototypes per `extend` block |
| P181 | Details of #169 | `b.match(&re)` loops `rx_search_bytes` as `s.match(&re)` loops `rx_search`, an empty match moving on by a byte, and `RegExp.bytesMatchAt` builds the `BytesMatch` with `rx_bytes_slice`; `split` is the Array form's walk over bytes | `replace` on a Bytes waits: a replacement of bytes would want its own spelling |
| P182 | Details of #170 | `b.replace(&re, &with)` and `b.replace(&re, text)` call `RegExp.replace(&b, p, n)` of the bytes and their count, the loop of a String's `replace` over `rx_search_bytes` with `rx_expand_bytes` for each match; the function form loops the same with `f(Self.bytesMatchAt(...))` | the byte-pointer form is a method the program may call as well, `re.replace(&b, p, n)` |
| P183 | Details of #171 | `RX_B` is 128 in the program's flags; `rx_search` and `rx_search_bytes` both set the matcher's `bytewise` from it, and `rx_slice` of a String aborts where a bound falls on a continuation byte | the flags are read by the parser shared with kelvinc, so `$/a/v` and a flag that is none are errors at compile time still |
| P184 | Details of #172 | `Bytes([a, b, c])` is `kv_bytes_from((const uint8_t[]){a, b, c}, 3)`; the parser keeps the list as an E_INIT in the call, marked `list` | an element that is a variable or an expression is converted by C as a `uint8_t` initializer is, the literals checked by kelvinc |
| P185 | Details of #173 | documents/README.md groups the documents as starting, values, reading and writing, and modules | the file is `README.md`, which GitHub shows at the top of the directory |
| P186 | Details of #174 | `kv_exit_failure` in runtime/bytes.c, declared by the prelude, flushes stdout and stderr, aborts where `KELVIN_ABORT` is set, else `exit(1)`; `rx_exit_failure` in runtime/regexp_parse.c is the same for the engine and kelvinc; the failure helpers of bytes.c, io.c, os.c, unicode.c and the engine call them, and the out-of-memory exits of unicode_data.c stay `exit(1)` | tests/run.sh reads `// exit: N` as the status a test expects and compares stderr with its `// err:` lines when it has any |
| P187 | Details of #175 | tests/asan.sh compiles runtime/*.c, the C of each module with a `.kh` by `kelvinc --lib --emit-c`, and each test's C by `kelvinc --emit-c`, all with `-fsanitize=address -Dmalloc=kv_cnt_malloc -Drealloc=kv_cnt_realloc -Dfree=kv_cnt_free -include stdlib.h`, links them with tests/asan/count.c and runs each, reading `allocations N, live at exit M` from stderr | `detect_leaks=0`, since the counter is the check and LeakSanitizer is not on macOS; the output of a test is not compared, which tests/run.sh does |
| P188 | Details of #176 | tests/docs.sh extracts the blocks with awk: a line at the margin that starts `#import`, `struct`, `union`, `enum`, `extend`, `typealias`, a function `let f(`, a method, attribute or type attribute `let T.x`, or a subscript `let T[]`, with the lines to its closing brace, is a declaration; the rest is indented into `let main():int32 { ... return 0 }`; a block compiles, and is not run | `DOCS_KEEP=dir` keeps the rearranged sources of the blocks that failed; a block the line `<!-- fragment -->` precedes is counted, not compiled |
| P189 | Details of #177 | `s.find(x)` is `KV_STRING_TEXT_OR_REF(find, &s, x)`, a `_Generic` choosing `kv_string_find_text` or `kv_string_find_ref`, and so for has, starts and ends; `s.trim()` is `kv_string_trim(&s)`; all in runtime/string.c | the parser lists them among a String's methods, with `has` and `find` shared with a Dictionary's and a Set's by the kind letter, checks the argument, and types `find` as `i64` and the others as `bool` |
| P190 | Details of #178 | the top-level `let` or `var` parse checks each variable: an initializer on a type `is_owner` sees is the error, at the initializer; the codegen lists the global owners, declares `_kv_free_globals`, writes it after the printers with each one's free, and has `main` call `atexit` on it first thing | a module built by `kelvinc --lib` has no main, so its globals are not freed; tests/asan/count.c registers its report in a constructor, so that it runs after the program's handlers |
| P191 | Details of #179 | `method_named` returns NULL where the receiver's type is seen and is not `T_BASE`; `method_candidates` already asked for `T_BASE`; the fuzz is a script of the session, not of the tree, run by hand | a fuzz in the tree would be a release check to add if one is wanted; the mutations are random, so a run is not repeatable without its seed |
| P192 | Details of #180 | `parse_nested_fn` saves the parser's state as `parse_anon_fn` does, sets `anon_start` past the function's own name, and calls `parse_fn` with `nested_outer` set, which marks `Decl.nested_in`; the Decl goes to `anon_fns`, so `add_top_decl` writes its prototype before and its definition after the enclosing declaration, the prototype copy named with its original after `name_functions` runs; `function_named` finds a nested function by the binding of its name, `Decl.bind_index`, and `overloads_of` gives that one alone where the name is bound in a block | the C name is `_kv_outer_name`, numbered for another of the name in the same outer function; a nested function is not overloaded, a second of the name in a block hiding the first |
| P193 | Details of #181 | `parse_primary` turns `$` before `(` into an E_IDENT of `parsing_fn`'s name with `target` the declaration and `op` "callee"; `resolve_call` sees the op first, checks the count of arguments, and resolves the call to that declaration, whose C name the codegen writes: `_kv_main_fn` for an anonymous function, `_kv_main_fib` for a nested one, `T__name` for a function of a type | `$` followed by anything else is as before: `$0`, `$[k]`, `$"..."`, `$[...]`, `${...}`, `$/.../` |
| P194 | Details of #182 | `xs.map(f)` is `({ __auto_type _kv_ms = &(xs); _kv_array_U _kv_mo = {0}; for (...) _kv_array_U_append(&_kv_mo, f(elem)); _kv_mo; })`, `elem` the element or `T_copy(&elem)` for an owner; `arithmetic_type` in the parser gives the result of `+ - * / %`, the bit operators and the shifts, unary `-` and `~`, of one seen number type, or with an integer literal, or a floating one with f32 or f64, and `parse_anon_fn` tries it after `inferred_type` where a map infers its result | `filter`, `reduce` and the like wait for a request; a `.map` of a fixed array is not here, an Array's alone |
| P195 | Details of #183 | `s + t` is an E_CALL `string_concat`, `({ kv_string _kv_cat = kv_string_copy(&s) or (s) or KV_STRING_OF(s); KV_STRING_APPEND(&_kv_cat, t or &t); _kv_cat; })`; the cstr and uchr operator checks let `+` through where a String is on either side; `xs.map` of a temporary is `array_map_tmp`, the Array held in `_kv_mt` with its free as the cleanup | `+` of a Bytes waits for a request; the error test of a map of an Array an expression gives, from #182, is gone |
| P196 | Details of #184 | `xs.filter(f)` is `({ ...; _kv_array_T _kv_mo = {0}; for (...) if (f(elem)) _kv_array_T_append(&_kv_mo, elem); _kv_mo; })`, an owner element copied for `f` and again for the new Array; `xs.reduce(init, f)` is `({ ...; U _kv_acc = init; for (...) _kv_acc = f(_kv_acc, elem); _kv_acc; })`, `f` taking the accumulator and giving the next, which moves an owner one through; the ops are `array_map`, `array_filter`, `array_reduce`, with `_tmp` for an Array an expression gives | an empty Array reduces to `init` |
| P197 | Details of #185 | `xs.sort()` is a `do { ... } while (0)` merging runs of 1, 2, 4, ... between the elements and a buffer of `kv_alloc`, moving the elements as bits, and copying back if the result ended in the buffer; `xs.sorted()` is the same on `T_copy(&xs)`, or on the Array an expression gives; the comparison is `f(right, left)`, the elements copied for `f` where they own, `kv_string_cmp`, `kv_bytes_cmp`, `strcmp`, `.cp`, the struct's operator `<` by its C name, or C's `<`; `s < t` is `kv_string_cmp(&s, &t) < 0` | `kv_alloc` in runtime/bytes.c allocates or ends the program with "out of memory", as the runtime's other allocations do; an `Array<uchr>` still prints its elements as `{...}`, a gap of the printer, not of the sort |
| P198 | Details of #186 | `xs.reverse()` is a `do { ... } while (0)` swapping `at[i]` and `at[j - 1]` from both ends; `xs.reversed()` the same on `T_copy(&xs)`, or on the Array an expression gives | the ops are `array_reverse`, `array_reversed` and `array_reversed_tmp` |
| P199 | Details of #187 | `make_temp(src)` binds `_kv_tmpN` of the source's type as a let and pushes an `E_TEMP{a: src, text: name, type}` onto `chain_temps`, the list of the postfix chain being parsed, set by `parse_postfix_chain` and `parse_postfix_ops`; `wrap_temps` puts the chain's result in each, the last innermost, refuses a pointer or an array result but a template's text, and marks the innermost `copy` where the result is an owner place; the codegen writes `({ __attribute__((cleanup(free))) T name = src; body; })`, the name an owner local while the body is written, so that a move out of it takes it; `fit` scores an owner an expression gives for a borrow of its type 1, and `borrow_temps` lends it after a call is resolved; `hold_operand` holds an operand in an operator's own list; `parse_for_each_held` puts a loop over an owner an expression gives in a block with a hidden let; `parse_var` keeps the index of its own binding, which a temporary bound in its initializer would otherwise take | `E_TEMP` is a new expression kind, its value type its body's, seen through by `arg_type`, `seen_bool`, `number_expr`, `is_text_expr`, `shown_type` and `has_effect` |
| P200 | Details of #188 | `b + c` is an E_CALL `bytes_concat`, `({ kv_bytes _kv_cat = kv_bytes_copy(&b) or (b) or kv_bytes_text(b); KV_BYTES_APPEND(&_kv_cat, c or &c); _kv_cat; })`; the cstr operator check lets `+` through where a Bytes is on either side; a literal byte out of 0 to 255 is an error | the table of bytes.md lists the orderings of #185 too, which it had left out |
| P201 | Details of #189 | `.gitattributes`: `*.k linguist-language=Swift` and `*.kh linguist-language=Swift`; 76 fences in 31 Markdown files changed to `swift`; tests/docs.sh matches ```` ^```(swift\|kelvin)$ ````, finding the same 72 blocks | GitHub's language bar counts the `.k` files as Swift; Design.md and Dialogue.md keep their words about ```` ```kelvin ```` as written then |
| P202 | Details of #190 | editors/vscode holds package.json (the language `kelvin` of `.k` and `.kh`, its grammar, the Markdown injection), language-configuration.json (comments, brackets, closing pairs, indentation), syntaxes/kelvin.tmLanguage.json and syntaxes/kelvin.markdown.json; tests/grammar.js applies match, begin and end with back references, captures, contentName and includes, as VS Code does, without Oniguruma, so the expressions keep to what JavaScript's and Oniguruma's share | a grammar for Linguist, so that GitHub colors Kelvin as Kelvin, waits until it is used widely enough |
| P203 | Details of #191 | tools/vsix.sh [out] writes [Content_Types].xml and extension.vsixmanifest (Identity, DisplayName, Description, the engine, and the assets package.json, README.md and LICENSE), copies editors/vscode and LICENSE under extension/, zips them and prints the path; its temporary directory is the one mktemp made or the script ends before its trap is set; `make vscode` asks for the `code` command where it is missing | publishing to the Marketplace, which needs a publisher's account and token, is the user's to do |
| P204 | Details of #192 | the test is `!defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)` in src/main.c, runtime/io.c, runtime/os.c and the head of the generated C, and `uname -s` in tests/asan.sh; F_KINFO fills a struct kinfo_file of sys/user.h, kf_structsize set first, where F_KINFO is defined; BSD make cannot read the Makefile, which is GNU make's | a FreeBSD job in CI, in a virtual machine; a Makefile that BSD make reads, handing to gmake |
| P205 | Details of #193 | Makefile names all, test, asan, vsix, vscode, install, clean and kelvinc, .PHONY, and sends any other target by .DEFAULT; GMAKE ?= gmake; a variable on BSD make's command line does not reach gmake, so README.md says to give it to gmake | the other BSDs' package names; Makefile not yet run by BSD make here, only by GNU make with -f Makefile |
| P206 | Details of #194 | vmactions/freebsd-vm@v1 on ubuntu-latest, its default release, usesh, copyback false; `pw useradd kelvin -m`, the checkout chowned to it, `su kelvin -c` for the build, `make test` and examples/hello.k; the tests tell FreeBSD by `strcmp(SYS.platform, "freebsd")` | f.abspath keeping the last name it found, so FreeBSD answers a removed file too; tests/asan.sh on FreeBSD |
| P207 | Details of #195 | `char *named` is the last field of kv_io; `remember` copies each name kv_io_abspath gives back, of realpath or of the descriptor; kv_os_mkstemp sets it NULL with the rest; remove and rename go by name_of, which asks kv_io_abspath, so a removed file's remove goes to the name it had on FreeBSD as on Linux; tests/run/io_abspath_kept.k | the name at open, so an IO never asked answers a removed file too |
| P208 | Details of #196 | kv_io_open sets `named` to realpath(path, NULL) once fopen succeeds; kv_io_fdopen asks kv_io_abspath and frees what it gives; kv_os_mkstemp, in libkOS, which libkIO links and not the other way, calls realpath itself; kv_io_rename sets `named` to the realpath of the new path; tests/run/io_abspath_open.k | — |
| P209 | Details of #197 | the lexer reads the block as one token, TK_INLINE_C, its text the C between the braces; the parser makes a D_INLINE_C at the top level and rejects it inside, as #import; codegen writes it after a `#line` of its first line and maps the next declaration anew; the .kh writer skips it; the grammar's `inline-c` embeds `source.c` in meta.embedded.block.c, counting braces itself, and tests/grammar.js, which has no C grammar, skips another language's include and treats a begin/end repository entry as one rule | `#inline C` inside a function, as a statement; its names in a module's .kh |
| P210 | Details of #198 | S_INLINE_C, its text in Stmt.name; parse_stmt_here makes it, parse_block_rest lets it through where #import is rejected, and a body of a statement or a label rejects it; codegen writes it after the `#line` of its statement and maps the next one anew | a C `return` of an owner, which kelvinc does not see |
| P211 | Details of #199 | c_declarations in parser.c: the comments made blanks; at depth 0, a line starting with `#` is kept with its continued lines; a `{` after `)` is a function's body, its text before it the prototype; else a declaration ends at `;`: kept as it is where it begins with `typedef`, `extern` or `_Static_assert`, or is a `struct`, `union` or `enum` with nothing after its `}`; else `extern` before it and each initializer dropped, up to the next `,` at depth 0; `static` or `inline` among its specifiers leaves it out; tests/project/lib/geo.k and geo_user.k use it, and tests/run.sh checks geo.kh | — |
| P212 | Details of #200 | c_declaration skips the storage class and qualifiers (static, extern, const, volatile, _Thread_local) to find struct, union or enum; its body is a `{` after the keyword and an optional tag alone; nothing after the body: the type, kept; a declarator after it: extern; static or inline with a tag and a body: `struct p { ... };`, the type alone; tests/project/lib/geo.k has both, which tests/run.sh checks in geo.kh | — |
| P213 | Details of #201 | `struct node { kind: uint8; fun: int64; arg: int64 }` in `var pool:$[node]`, a global owner filled by main; `step` unwinds the spine into an Array of arguments, the last first, and reduces I, K or S at the head, else the first argument that steps; `normal` stops after `limit` steps with " ..."; `show` puts an argument that is an application in parentheses; a node's kind is a `uint8`, shown by `.uchr`, since a character literal is C's `int` and a `uchr` C's struct | — |
| P214 | Details of #202 | `struct node { kind: uint8; n: int64; a: int64; b: int64 }` in `var pool:$[node]`, names in `var names:$[String]`, definitions in `var defs:$[int64]`, all global owners; a definition is closed, so its node is shared where its name is read; shift and subst as Pierce has them; `show` primes a binder whose name a binder around it or a free variable has; the reader's functions take a `reader^`, since a method cannot change self, and `term` is a prototype first; `kelvinc --run file -- args` passes args, which ski.k's comment now says too | — |
| P215 | Details of #203 | owner_place of a ?: (not `??`) is that of both arms; a ?: whose arms differ so is listed with its place's name, return_owner takes it off and moves each arm, and implicit_return reports what is left once a body is read, since only then is it known what is returned; codegen's moves_out and moved_out write `c ? take(&a) : b`; the Array append's `x->c` mark is not a ?:'s arm; tests/run/owner_choice.k and tests/error/owner_choice_*.k | — |
| P216 | Details of #204 | lex.k: one Array of codepoints for every file, tokens by offset, a newline token outside ( ) and [ ]; parse.k: nodes and types in Arrays by index, children set through set_a and its kin; gen.k: type_of and gen_expr, owners freed by cleanup, Strings compared through temporaries, a value computed before an Array element it is assigned to; kc.k: `-o`, `-c`, `-m`, `-cc`, imports read after the main file, since kc writes every struct, Array and prototype first; build/selfhost/ holds the stages | the rest of the language (selfhost/README.md) |
| P217 | Details of #205 | element_first in codegen.c, before a statement of an assignment or a method: where its place is in an Array's or a Bytes's elements (in_elements) and its value calls (calls_in: a call or a method without op, or with a target or a method; a temporary by what it holds; an E_STRING's items are its text), it writes `{ __typeof__(place) _kv_value = value; place = _kv_value; }`, or `__auto_type _kv_arg` for each argument that calls; tests/run/element_first.k | — |
| P218 | Details of #206 | element_copy in parser.c turns a borrow whose pointee is the element's type into an E_CALL of op element_copy, its type the element's, at `+=` and at `.append` and `.insert`; codegen writes the type's _copy of the pointer, or `*(p)` of a type that does not own; tests/run/append_borrow.k | — |
| P219 | Details of #207 | lex.k: `:=`; parse.k: D_IMPORT flag 2 of a name ending .h, `c_headers`, N_NULL, Y_C, `:=` in a variable; gen.k: an unknown name or call is Y_C where `c_headers`, a struct type no struct declares is a C typedef, `#include` of the header; kc.k: env_or, append_int, `-m` from `$KELVIN_HOME/modules`; sample.k uses strlen, abs, getenv and size_t | mkdtemp, exit |
| P220 | Details of #208 | a document, no code: listed in documents/README.md and versusC.md; c-contract.md's fences are `c` and `sh`, which tests/docs.sh does not compile | — |
| P221 | Details of #209 | parse_assign reads the place; where it is held in temporaries and an assignment follows, assign_to, the rest of what parse_assign was, builds the assignment of the innermost temporary's body, which becomes that temporary's body, and the innermost's copy of the place is undone; tests/run/dict_key_held.k | — |
| P222 | Details of #210 | parse.k: D_ENUM, its enumerators N_ID nodes with a value or -1; S_SWITCH and S_CASE, a case's values and its statements up to the next case, flag 1 of default; gen.k: enums written before the structs, an enumerator's type its enum, `enum t` of a type an enum names, gen_switch as kelvinc writes it, `default: __builtin_unreachable();` where every enumerator is named; put_elem_name, put_ctype, put_free and gen_stmt are switches; sample.k has an enum with `= 5` and switches on it and on a number | an enum with values in kc |
| P223 | Details of #211 | Y_DICT, its value elem and its key name; `${` lexed as one token; type_of_kind tells Dictionaries by their key; gen_key passes a String key as its text, kv_bytes_cstr; put_owner_prefix names an owner's functions; a Dictionary's entry counts with an Array's element for the value-first rule of #205; index_names fills fn_names, global_names, struct_names, enum_names and enumerators, each name's first declaration kept; sample.k has Dictionaries of String and of int64 keys | locals by name |
| P224 | Details of #212 | gen.k: N_BOOL as `((bool)true)`; gen_call refuses an argument of an owner type that is no place; put_int is `out += String(n)`; kc.k: `cfile += String(getpid() as int64)`; sample.k: String of a negative number, a number, a uint8 and a bool | holding an owner an expression gives, in kc |
| P225 | Details of #213 | parse.k: N_SELF; parse_extend and `let T.m(` put each function into decls as a D_FN whose c is T's token, flag 1 where static; `self_name` makes Self while one is read; `.x` at an expression's start is N_FIELD of N_SELF; gen.k: method_names by "T.m", method_of for x.m and T.f, gen_signature writes T__m and `struct T self` first, is_main of no receiver; sample.k has methods, a function of the type, `let point.dot`, and calls on a pointer's value and an Array's element | methods of a type that is not a struct |
| P226 | Details of #214 | parse_var reads `:T` where it is written, and keeps 1 in c of `:=`; parse_typed asks a parameter or a member for its type; gen.k's inferred finds the type when the variable is written, and the global's before the functions; gen_call counts println's values; sample.k infers ten kinds of value | `.count` as a size_t |
| P227 | Details of #215 | parse_enum: a case with `: T` makes the enum's flag 1 and is the case's ty; `;` separates cases; gen.k: tagged_of, tagged_named, case_named, case_tag, tagged_owns; is_owner and put_owner_prefix take an enum with values, and put_free_copy gives KV_ARRAY and KV_DICT an element's free and copy; gen_tagged writes it in the order of the structs; gen_switch switches on `.tag`, `case 1 /* num */:`, and binds `V x = v.u.c`; sample.k has one with an owning case, in an Array too, and kelvinc's and kc's builds of it both leave nothing live at exit | — |
| P228 | Details of #216 | count.c defines the feature macros realpath needs, kv_cnt_realpath, and on macOS the same by the name stdlib.h links it as, kv_cnt_realpath$DARWIN_EXTSN; asan.sh adds -Drealpath=kv_cnt_realpath and fails on a negative count; realpath is the runtime's only libc call whose block it frees, glob's being globfree's | — |
| P229 | Details of #217 | lex.k: `??`, and eof_pos, the end of the files' tokens, after which made_token puts the names kc makes, which the parser's cursor never reaches; parse.k: optional_of and result_of make an enum once each, by name, in made_enums, its c 1 of an Optional; S_IFLET; `??` binds tighter than a comparison and looser than `+`; gen.k: gen_value makes a case where a type expects one, by gen_var, gen_return, gen_assign and gen_args_to; gen_coalesce reads x once, an Optional that owns refused; gen_iflet holds what an expression gives and frees it; an owning enum with values is assigned as kelvinc's _assign does | kelvinc's own message for a bare some(v); Optional<T>.some(v) in kc |
| P230 | Details of #218 | parser.c: place_follows decides, after `]` of a Dictionary, whether d[k] is a place or read whole, a dict_lookup of type V?; unwrapped builds x.some's E_FIELD, holding an owner an expression gives (#187), and keeps d[k] the place; chained reads the rest of the postfix chain of a hidden binding, `_kv_chainN`, of the value, and copies a member that owns out of it; `&` of a dict_lookup is its place; reject_record_mismatch refuses an Optional where a non-Optional goes, in variables, assignments and returns; `??` wraps its default where the value is an Optional; codegen.c: dict_lookup and chain by the Dictionary's _find, the Optional read once; tests that printed d[k] read d[k]!; kc: x!, and d[k] read whole refused | kc making d[k] an Optional; `x?` alone, which `x` already is |
| P231 | Details of #219 | parse.k: Dictionary<K, V> makes optional_of(V); gen.k: type_of of a Dictionary's N_INDEX of flag 1 is V?; gen_lookup writes `({ __auto_type _kv_p = D_find(&d, k); _kv_p ? make_some(*_kv_p or T_copy(_kv_p)) : make_none(); })`; is_place is false of it; gen_value refuses an Optional where a non-Optional goes; sample.k reads counts["c"], counts["none"] ?? -1 and if let some(t) = tags[3] | kc's `x?.m`; kelvinc's strings of `??x`, which C11 reads as trigraphs |
| P232 | Details of #220 | lexer.c: untrigraphed(s, n) puts a backslash before each `?` after a `?`; lex_quoted's tokens and #inline C's text go through it; a `??` in #inline C's code and in a C header's name is an error; codegen.c: c_file_name escapes `"`, `\\` and `??` of both #line writers, the pinned one escaped now too; parser.c: .typename's literal; gen.k: put_text of N_STR and N_DSTR; tests: run/no_trigraphs.k, error/inline_c_trigraph.k, error/import_trigraph.k | trigraphs in a header kelvinc does not write, which are C's |
| P233 | Details of #221 | parse.k: parse_steps(first), N_CHAIN (t the ?, a the source, b the rest, c the made name `_kv_chainN`), `$[T]?`; gen.k: chain_type binds the name in a scope of its own and gives optional_of(T) or the rest's Optional; gen_chain writes `({ R _kv_rN; [cleanup] S _kv_sN = x; if (_kv_sN.tag == 1) { T name = _kv_sN.u.some; _kv_rN = make_some(rest or T_copy(&rest)); } else _kv_rN = make_none(); _kv_rN; })`; gen_program writes the functions first into a String of their own and the enums made meanwhile before them; holds_kind orders enums after the Arrays and the Dictionaries they hold; is_case_word keeps none, ok(v), err(e) from type_of in gen_call and gen_return; gen_coalesce keeps its serial | kc: none in a struct's {a, b}; freeing a struct whose fields own; `.copy()` of an Array; kelvinc: `f(none)` of a T? parameter, a C error |
| P234 | Details of #222 | parser.c: wrap_variant_args(call, d) applies optional_of(string_of_literal(x, t), t) to each argument of an Optional or Result parameter, in resolve_call before the record checks of one function and after choose, and for a method chosen; fit gives a bare none 1 of an Optional, else 0, and ok(v)/err(e) 1 of a Result whose case v fits; fit_wraps, set by choose for a second choose_among where the first found nothing, lets a T fit a T? as 1; the tie of a bare none names Optional<i64>() | f("text") among overloads with a String parameter, which goes to C |
| P235 | Details of #223 | parser.c: resolve_call calls the one Kelvin function, an argument that is no struct where it takes one an error naming the declaration of C's; among overloads no fit is an error (a type's function, `T.f`, without C's hint), after an owner where one takes a borrow of it, which says `&x`; pick_overload errs where no overload has the type; typed_args (was wrap_variant_args) also makes a String of a text literal; fit gives a text literal 1 of a String; reaches_c, the dispatched list and Expr.c_too are gone, and codegen's generic_tree defaults to kv_no_such_overload; tests overload.k and overload_unseen.k declare C's sqrt, fabs, sin, abs and hypot | — |
| P236 | Details of #224 | parser.c: some(x) of one argument is an E_CALL of op word where no function or binding has the name; optional_of refuses some(v) of an Optional and of a Result at the word; codegen.c: an E_CALL of op word left, ok, err or some, is an error at its word; tests: error/some_value.k, some_alone.k, ok_alone.k, result_some.k | — |
| P237 | Details of #225 | gen.k: is_owner of a Y_STRUCT asks its D_STRUCT's members; gen_struct_owner writes _kv_T_free, _take and _copy; write_type(y) writes a type's C once, kept in `written`, after its element, members, key and value or cases, a pointer recursing into nothing; gen_program writes the structs and enums with values, the Arrays and the Dictionaries through it, and the T? made late too; holds_kind is gone; gen_assign's free-then-set covers any owning struct; gen_value of N_INIT for a struct is gen_init, each member by its field's type, a local owner an error; sample.k: struct pet | a by-value owner parameter, which kc does not free; `.copy()` of an Array |
| P238 | Details of #226 | gen.k: gen_signature names an owner parameter _kv_x_in; takes_owner(d); gen_function opens a block that binds each to a cleanup local before the body; gen_args_to moves a whole variable by _take and refuses a place; gen_call's bind-it error skips a by-value owner parameter; gen_method passes a method's arguments by gen_args_to; .copy() of any owner but IO is PREFIX_copy(&x); sample.k: shout, sum_of, fibs.copy() | kc holding temporaries (#187) |
| P239 | Details of #227 | gen.k: needs_hold(n): no case word, no place, an owner; hold_open/hold_close write the statement expression and mark the node in `held`, whose number gen_expr writes; hold_args holds a call's arguments not taken by value, and the base of `&`; gen_field and gen_method hold their receiver (gen_member, gen_method_of), gen_index an element's base (gen_element), copying out an owner; gen_string_eq holds either side; gen_each holds its source as a local of its block; S_EXPR frees an owner it drops; is_place of a member or element asks its base; index_names indexes what is declared since, and decl_named asks it; sample.k: println(String(42), shout($"x").count, adopt("ace").name, ...) | kc printing an Optional |
| P240 | Details of #228 | .github/workflows/ci.yml: the job selfhost, a matrix of ubuntu-latest gcc, ubuntu-latest clang and macos-latest clang: make, selfhost/bootstrap.sh, selfhost/sanitize.sh; selfhost/sanitize.sh: build/selfhost/kc-sanitized from stage2.c with -fsanitize=address,undefined -fno-sanitize-recover=undefined, ASAN_OPTIONS=detect_leaks=0, its C of kc.k compared with stage2.c and of sample.k with sample.c | the counting allocator's run of kc's programs in CI |
| P241 | Details of #229 | gen.k: need_show(y, n) gathers the enums with values and structs print needs, an error where one holds what kc cannot show; gen_show writes `_kv_show_T(kv_out *o, const void *_kv_v, int level)` by show_value: kv_cstr_i64, kv_cstr_u64, kv_cstr_bool, kv_out_quoted, kv_out_quoted_text, or another _kv_show_T, a struct's members between kv_out_sep and kv_out_end; gen_print_args writes `({ __auto_type _kv_sv = (x); _kv_show_T(&(kv_out){.fp = NULL, .width = 2}, &_kv_sv, -1); (const uint8_t *)""; })`; gen_program declares them before the functions and writes them after; fits_value; gen_value writes some's value by its case's type; names_type knows an enum with values; parse.k: `??` in a type is two `?` | kc printing an Array |
| P242 | Details of #230 | gen.k: shown_by_type(y) is true of an Array too; need_show checks an Array's element; put_show_name of an Array is `_kv_show_` and its C name; put_self(path, t) writes self->path and a name; show_value takes `at[_kv_i]` with no name; gen_show of an Array writes `[]` where empty, else `[`, each element after kv_out_sep(o, level, _kv_i == 0), kv_out_end, `]`; README.md, selfhost/README.md and selfhost/kc.k say experimental; sample.k prints fibs, an empty Array, points and hay | — |
| P243 | Details of #231 | selfhost/README.md: "The size of the language" says 17,700 and 12,300 lines of kelvinc, 3,900 of kc, a list of what the subset took in, a list of what it leaves out, 834 tests; "Speed" says about 12 ms a compile at 3,900 lines; "Next steps" names `c ? a : b` first | — |
| P244 | Details of #232 | parse.k: N_COND (a the condition, b and c the arms, t the ?); parse_expr parses one after parse_binary(1), its arms by parse_expr; gen.k: type_of, is_place of both arms, has_call of the second; gen_choice writes `(c ? a : b)` read; owner_choice refuses a place and a value; gen_value writes each arm by the type that takes it and refuses two places of an owner; gen_return of an owner's choice is gen_moved, which takes a local owner by _take; gen.k uses ?: five times; sample.k: either, half, parity, nested choices | kc's `let s:cstr =`, which kelvinc refuses |
| P245 | Details of #233 | parse.k: `:=` is an assignment's operator; gen.k: type_text(y) spells a type as kelvinc's messages do (i64, cstr, i64^, $[String], i64?, Result<i64, String>); assigns_as(n, t, y, colon) checks gen_var, the globals and gen_assign to a name or a member; put_op writes := as C's =; sample.k: parity := ... | — |
| P246 | Details of #234 | gen.k: count_overloads fills fn_sigs (name and signature: the first declaration), fn_bodies and fn_overloads; mangled(y) and params_key(d) spell a C name's types; put_fn_name(d) names a defined overload; arg_fit(a, t, wraps) and choose_overload(n, name, wraps) score and choose, a second look letting a T fit a T?; call_target(n), kept in `targets`, is the function of type_of and gen_call; gen_value makes a String of a text literal; gen_call refuses a call of a name a variable hides; sample.k: twice and kind | methods' overloads; kelvinc's names of an imported file's functions; `x == none` in kc |
| P247 | Details of #235 | kelvin.h: Type.eq; parser.c: == and != of two Dictionaries call `_kv_dict_K_V_eq(&a, &b)`, operands an expression gives held; eq_type of a Dictionary is its values'; parse_program sets each registered Dictionary's eq once parsing is done; codegen.c: emit_dict_eq after KV_DICT and KV_DICT_FUNCS, its values by eq_code, with a prototype of an enum value's _eq, and of its own after KV_DICT_TYPE; eq_code of a Dictionary is its _eq; documents/dictionaries.md | — |
| P16 | `#import` details | `#import "x.h" as C` | Top level only, at the start of a line. A quoted header is searched next to the `.k` file (kelvinc passes `-I<dir of .k>`), since the generated C lives in a temp directory |
| P17 | `as` binds tighter than every binary operator and looser than prefix operators, and chains left to right | `-x as u8` is `(-x) as u8`; `a * b as i64` is `a * (b as i64)`; `x as i64 as i32` | This is where C's cast sits (and Rust's `as`). To index or dereference the result, parenthesize: `(p as u8^)[0]`, because a `[`…`]` or `^` after the type is read as part of the type |
| P18 | `T(v)` only for built-in types (`i8`…`u128`, `f32`, `f64`, `bool`) | `u8(c)`, but `n as size_t` and `p as u8^` | For a typedef name, `size_t(n)` would look exactly like a function call, and suffixes such as `u8^(p)` read poorly. `as` covers every type |
| P19 | Compound literals `(T){...}` stay, for any type (including typedef names with suffixes or qualifiers) and under `sizeof`; an array's is `([T])[...]` since #48 | `(struct point){.y = 7}`, `([size_t])[1, 2]`, `(div_t^){NULL}`, `sizeof ([i32])[1, 2, 3]` | They are not casts, although they share C's syntax. A `(...)` followed by `{` can only be a compound literal, because an expression is never followed by `{`, so its contents are read as a type; `(...)` followed by `[` is one where the parentheses hold a type that ends with `]` (P60). A Kelvin spelling is an open question (Q10) |
| P20 | C compiler keywords beyond C11 are rejected | `__extension__`, `__real__`, `__imag__`, `__alignof__`, `alignof`, `__typeof__`, `typeof`, `_BitInt`, `__int128` (use `i128`), `__signed__`, `__complex__`, `__auto_type`, `_Float16`, ... | In C they act as prefix operators or type specifiers, which would let a C cast or a prefix `*` dereference through (#14). `__asm__(...)` and `__attribute__((...))` stay usable, and `_Pragma("...")` is allowed as a statement of its own |

## Open questions

- ~~**Q1: Drop `var` as well?**~~ Answered: yes (#15).
- ~~**Q2: `i64`-style type names?**~~ Answered: yes, see changes #6–#8.
- ~~**Q3: `float`/`double`?**~~ Answered: `f32`/`f64` (change #9).
  `long double` has no Kelvin spelling yet.
- ~~**Q4: `_Bool`?**~~ Answered: built-in `bool` (change #10).
- **Q5: `size_t`?** `sizeof`, `malloc` and `strlen` all use it. Should Kelvin
  have `usize`/`isize`, or should programs use `u64`/`i64`?
- ~~**Q6: Integer literal suffixes.**~~ Answered: no suffixes at all (#13).
- ~~**Q7: Printing `i64`.**~~ Answered by #17: `print()` and `println()` in
  the prelude.
- ~~**Q8: Infer more than integers?**~~ Answered: no. Only integer (`i64`)
  and floating (`f64`) literals are inferred (#8, #11), and `bool` must be
  written.
- ~~**Q9: Casts to C typedef names.**~~ Answered by #14: `n as size_t` and
  `p as FILE^` parse, because a type is certain after `as`.
- ~~**Q11: C globals from headers.**~~ Answered by #27: a plain
  `optind = 1;` only assigns, so it reaches the header's global.
- **Q12: Infer from typed variables?** kelvinc now knows the declared type
  of every variable in scope (#19). Should `var n := list` infer `n`'s
  type from `list`, as `var n:struct node^ := list` currently spells it?
  Today only literals, `bool`s (#24, #25), annotated values (#8, #11,
  #15) and anonymous functions that write their parameters (#32) are
  inferred.
- ~~**Q13: `(p0 - p1).diff`.**~~ Set aside by the user (Dialogue.md
  entry 59): the difference of two pointers as a `.diff` property, a
  `ptrdiff_t`, is not planned for now.
- **Q14: Which conversion is nearer?** An `i32` fits `twice(n:i64)` and
  `twice(x:f64)` alike, so `twice(n)` is an error asking for a
  conversion, as C++ would have it (P52). Should a number prefer a
  parameter of its own kind, an integer an integer and a float a float?
- ~~**Q15: A codepoint type?**~~ Answered by #56: `uchr`, printed as its
  character, with `.utf32` and `.codepoint` as the number.
- **Q10: Compound literals.** `(struct point){.y = 7}` keeps C's
  cast-like syntax (P19). Should it get a Kelvin spelling, such as
  `struct point{.y = 7}`?

## Ownership (#54)

The rules O1 to O10, proposed here on 2026-10-09 and agreed, are in
[documents/ownership.md](documents/ownership.md); their details are
P66. Later owners (`String`, `Array`, `Dictionary`) follow them.

## Unchanged from C (on purpose, for now)

These are everything else: operator precedence (including `==` binding
tighter than `&`), implicit conversions, integer promotion (to C's `int`,
which is `i32` on every supported target), the comma operator,
`?:` (with a `bool` condition, #23), `for`/`switch`/`goto`, compound literals, designated initializers, arrays that
decay to pointers, declare-before-use, `struct`/`union`/`enum` tags (also
types by their bare name since #29), and all
undefined behavior.

## TODO (C features not yet expressible in Kelvin)

- The rest of the preprocessor (`#define`, `#if`, ...). Headers are
  covered by `#import ... as C`.
- `sizeof` of a type spelled from a C typedef plus a suffix, e.g.
  `sizeof(FILE^)`. Kelvin reads it as dereferencing a variable named
  `FILE`. `sizeof(size_t)` works, and so does `sizeof p` for a variable
  `p:FILE^`.
- `typedef`
- An array of functions, or a pointer to a function type (#31)
- Bit-fields
- Nested or anonymous struct/union definitions inside other declarations
- `inline`, `restrict`, `register`, `_Alignas`, `_Static_assert`,
  `_Generic`, `_Atomic`, `_Thread_local`, `_Noreturn`
- String prefixes (`L"..."`, `u8"..."`)
- Unnamed parameters in prototypes
- Local struct/union/enum definitions (only top-level definitions work)

## Ideas tried in v0.1 and set aside

The first cut (PR #1, before this reset) went much further than bare C.
These features were removed, and any of them could come back only as an
individual proposal:

- runtime traps instead of undefined behavior (overflow, bounds, null)
- slices `[]T`, arrays as values, `defer`, `let` (immutability)
- `i32`/`u8`-style type names, wrapping operators `+%`
- stricter typing (no implicit conversions, `bool`-only conditions)
- order-independent declarations

## Implementation

| File | Role |
|------|------|
| `src/lexer.c` | C's lexical rules, template literals (#39), and `#import` of Kelvin files (#40). Kelvin keywords `as`, `i8`…`u128`, `f32`, `f64`, `bool`, `true`, `false`, `String` (shelved), `any`, `nullptr`, `cstr`, `let`, `var`; `..<` and `...` for ranges; `$`, `$0`, `$1`, ... for anonymous functions; `~=`, no `^=`; a number ends before `.name` (P30) |
| `src/parser.c` | Recursive descent over C's grammar with the changes above, template literals included (#39), plus a table of declared names, their types and which are lets: it checks `=` against `:=` (#19), assignments to lets (#27) and what anonymous functions use (#32), infers types (#25, #28, #32), lists the anonymous functions around each top-level declaration, and chooses among overloaded functions and operators by the types it sees (#41, #42) |
| `src/codegen.c` | Prints C: methods and properties become `_Generic` dispatch, every struct gets a derived `.cstr` and its size, property buffers are declared at the top of their block, and anonymous functions become static functions, declared before their declaration and defined after it; template literals build their text in the statement expression and copy it into storage at the top of their block (#39, #44), and everything kelvinc names itself is `_kv_` (#38); a call whose overload only C can tell is a choice over the arguments kelvinc cannot see, by `_Generic` and `__builtin_choose_expr` (#41, #42); postfix and function types become C declarators, `i32` becomes `int32_t` and `f64` becomes `double`, `p^` becomes `(*p)`, `~` becomes `^` |
| `src/main.c` | Driver: puts imported Kelvin files after their imports, from `./modules` or Kelvin's `modules/` for `<x.k>`, marking where each ends (#40, #46), writes the C, finds the runtime in Kelvin's `modules/`, runs `$CC` with `-I<dir of .k>`, `-I` and `-L` of the `modules/` directories, `-ffp-contract=off` (P55) and `libkelvin.a`, and optionally runs the program |
| `modules/kelvin_prelude.h` | The prelude: `print`/`println` as `_Generic` macros, the dispatch tables for `.cstr`, `.dec`, `.hex`, `.oct` and `.bin`, `kv_typename` for `.typename`, the `KV_TEXT_` macros that read numbers from text (#36), and `KV_HEX_DEFAULT` for `.hex` of pointers (#37), `KV_TEMPLATE_BUILD`, `KV_TEMPLATE_VALUE` and `KV_TEMPLATE_BOUND` for template literals (#39, #44), and `KV_NUMBER`, `KV_POINTER`, `kv_no_such_overload` and `kv_no_such_operator` for choosing overloads in C (#41, #42) |
| `runtime/prelude.c` | `print`/`println`, and the text of template literals, which shows values as `print` does (#39), written into the caller's buffer with nothing allocated (#44), built into `libkelvin.{a,so,dylib}` |
| `runtime/string.c` | The text of values: `.cstr`, `.dec`, `.hex` (also of pointers, #37), `.oct` and `.bin`, and numbers from text (#36) |
| `modules/complex.k` | `complex32` and `complex64`, their operators and elementary functions (#43), for `#import <complex.k>` |
| `modules/libkelvin.*` | Built by `make` from `runtime/` (#46) |
| `tests/run.sh` | `tests/run/*.k` check output and, with `// c:` lines, the C written; `tests/project/*.k` check output, built from inside a copy of `tests/project`, whose `modules/` is `./modules`, with a library built into it, and Kelvin's `modules/` as `make install` lays it out is found next to kelvinc and through `KELVIN_HOME` (#46); `tests/error/*.k` check diagnostics, and the Kelvin files both import are in `lib/` next to them; `tests/c/*.c` use libkelvin from C, linked statically and dynamically |

The driver adds `$KELVIN_CFLAGS` to the C compiler command line, after
the program's C, for libraries (`-lcurl`) and other flags. `--emit-c --no-line` shows the
generated C without `#line` directives.
