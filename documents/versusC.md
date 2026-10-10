# Kelvin versus C

This is a reference for C programmers. It lists every way Kelvin differs
from C, as of the current compiler. Anything not listed here works exactly
as in C, including the semantics, the ABI, operator precedence, implicit
conversions and undefined behavior.

The table below is the whole language at a glance; the documents beside
this one have the details, one topic each. Items marked *(provisional)*
were chosen during implementation and have not been agreed yet. See the
P-numbers in [Design.md](../Design.md).

## At a glance

| C | Kelvin |
|---|--------|
| `int x = 0;` | `var x:i32 = 0` |
| `const int k = 42;` | `let k:i32 = 42` (#27) |
| `long n = 42;` | `var n = 42` (inferred as `i64`) |
| `long *buf = malloc(n);` | `var buf := malloc(n):i64^` (`:=` for references) |
| `p = q;` (pointers) | `p := q` |
| `double d = 1.5;` | `let d = 1.5` (inferred as `f64`) |
| `unsigned long v = 10UL;` | `var v:u64 = 10` |
| `float f = 1.5f;` | `var f:f32 = 1.5` |
| `1UL << 40` | `1:u64 << 40` |
| `uint16_t u = 0xdead;` | `var u = 0xdead:u16` (inferred as `u16`) |
| `const char *s;`, `char *s;` | `var s:cstr` (immutable text, #52), or `var s:u8^` for bytes to write |
| `int a[4];` | `var a:[i32](4)`, or `var a = [i32](4)`, zero-filled (#49) |
| `int *a[4];` | `var a:[i32^](4)` |
| `int (*p)[4];` | `var p:[i32](4)^` |
| `const char *const s = t;` | `let s:const u8^ := t` |
| `long add(long a, long b) { ... }` | `let add(a:i64, b:i64):i64 { ... }` (parameters are lets) |
| `void f(void);` | `let f()` |
| `void *p = NULL;` | `var p:any^` (a reference is `nullptr` until assigned) |
| `(void *)0`, `NULL` | `nullptr` |
| `static int g(void);` | `static let g():i32` |
| `int main(int argc, char **argv)` | `let main(argc:i32, argv:u8^^):i32` |
| `struct p { int x, y; };` | `struct p { x: i32, y: i32 }` |
| `struct p q;`, `typedef struct p p;` | `var q:p` (a tag is a type by its bare name, #29) |
| `struct { double x, y; } v = {3, 4};` | `var v:{x:f64, y:f64} = {3.0, 4.0}`: one type per spelling, so it passes to `let f(v:{x:f64, y:f64})` (#59) |
| `union { int i; float f; } u;` | `var u:union{i:i32, f:f32}` (#60) |
| `struct { uint8_t tag; union { double n; ... } u; } j;` and a `switch` on the tag by hand | `enum json { null; n: f64; s: String; a: Array<json> }`: `json.n(1.5)`, `j.is(n)`, `j.n` checked, `switch j { case n: ... }` (#61) |
| `switch (n) { case 1: case 2: ...; break; default: ... }` | `switch n { case 1, 2: ... default: ... }`: a case ends at the next, no fallthrough, every value handled (#63) |
| `*p` | `p^` |
| `**pp` | `pp^^` |
| `*p++ = *q++;` | `p^ = q^; p++; q++` (`++` is a statement, for pointers, #26, #51) |
| `i++`, `--n` | `i += 1`, `n -= 1` (statements) |
| `x = 1; y = 2;` on two lines | `x = 1` and `y = 2`: a line ends a statement (#35) |
| `long square(long x) { return x * x; }` | `let square(x:i64):i64 { x * x }` (#35) |
| `for (int i = 0; i < n; i++)` | `for i in 0..<n { ... }` (#28) |
| `for (int i = 1; i <= n; i++)` | `for i in 1...n { ... }` |
| `for (p = s; *p; p++) { c = *p; ... }` | `for c in s { ... }` (#30) |
| `for (n = head; n; n = n->next)` | `for n in head { ... }` |
| `p->m` | `p^.m` |
| `a ^ b`, `a ^= b` | `a ~ b`, `a ~= b` |
| `(unsigned char)c` | `u8(c)` or `c as u8` |
| `(int *)malloc(n)` | `malloc(n) as i32^` |
| `(size_t)n` | `n as size_t` |
| `strtol(s, NULL, 8)`, `atof(s)` | `i64(s, 8)`, `f64(s)` or `s.f64` (#36) |
| `snprintf(buf, n, "%s: %d", name, n)` | `` `${name}: ${n}` `` (#39) |
| `(uintptr_t)p`, `printf("%p", p)` | `p.addr`, `print(p.hex)` (#37) |
| `#include "x.h"` and a separately compiled `x.c` | `#import "x.k"`, `#import <complex.k>` (#40, #46) |
| `csin(z)` beside `sin(x)` | `let sin(z:complex64):complex64 { ... }` beside C's `sin` (#41) |
| `cadd(a, b)` | `a + b`, given `let +(a:complex64, b:complex64):complex64 { ... }` (#42) |
| `double complex z = 1.0 + 2.0 * I;` | `let z:complex64 = complex64(1.0, 2.0)` (modules/complex.k, #43) |
| `sizeof(long)` | `sizeof(i64)` |
| `#include <stdio.h>` | `#import <stdio.h> as C` |
| `printf("%" PRId64 "\n", n)` | `println(n)` (prelude, no import) |
| `snprintf(buf, sizeof buf, "%lld", n)` | `n.cstr` (`cstr` text on the stack) |
| `strlen(s)` | `s.count` (measured once per scope, #52) |
| `char *buf = malloc(n); ... free(buf);` | `var b = Bytes(n)`, freed when its block ends (#54) |
| a UTF-8 string by hand | `var s = String("héllo")`, or `$"héllo"`, `for c in s { }` by codepoint, `s.count` (#55, #62) |
| `uint32_t cp`, encoded by hand to print | `uchr`: `print(c)` shows the character, `c.utf32` the number (#56) |
| `T *xs = malloc(n * sizeof *xs); ... realloc ...` | `var xs = Array([1, 2, 3])`, or `$[1, 2, 3]`, `xs += x`, `xs[i]` checked, freed by its block; the type is `Array<i64>`, or `$[i64]` (#57, #58, #62, #64) |
| a hash table by hand, or a library's | `var d = $["ann": 31]`, `d["bob"] = 42`, `d["ann"]` checked, `d.has(k)`, `d.find(k)`, `for k, v in d`, `d.keys`, `d.values`; the type is `Dictionary<String, i64>`, or `$[String: i64]` (#65, #66) |
| `snprintf` into a buffer sized by hand, or `asprintf` | `` var s = $`${name}: ${n}` ``, a String with no bound (#67) |
| `realloc`, `strcat` | `b += "more"`, `b.append(x)`, `b.insert(i, x)`, `b.remove(i, n)` |
| `sizeof x` | `x.size` |
| `__typeof__(x) y;` | `var y:x.type` (#34) |
| `snprintf(buf, sizeof buf, "0x%x", n)`, `n` unsigned | `n.hex` (`u8^` text on the stack; a signed `n` gives `+0x2a` or `-0x2a`) |
| `double area(struct shape s)` | `let shape.area():f64 { ... self ... }`, called as `s.area()` |
| `int (*cmp)(const void *, const void *);` | `var cmp:(const any^, const any^):i32` (#31) |
| a `static` function written only to be passed | `sort(xs, n) { $0 < $1 }` (an anonymous function, #32) |

## The documents

| Document | Covers |
|----------|--------|
| [grammar.md](grammar.md) | declarations, type inference, expressions, lines and `;`, assignment as a statement, C habits kelvinc catches |
| [operators.md](operators.md) | every operator, C's precedence, what moved: `^`, `~`, `&`, `as`, `:=`, `p++`, ranges |
| [integers.md](integers.md) | `i8`…`u128`, `f32`, `f64`, `bool`, literals, conversions, numbers from text |
| [pointers.md](pointers.md) | `T^`, `:=` for references, `any^`, `nullptr`, `.next`, `.prev`, `.isNull` |
| [dictionaries.md](dictionaries.md) | `Dictionary<K, V>`, `$[K: V]`: entries, lookup, `keys` and `values`, walking |
| [arrays.md](arrays.md) | `[T]` and `[T](N)`, `[...]` initializers, `.count`, `[T](n)`, arrays and pointers; `Array<T>`, `$[T]`, the growable one on the heap |
| [cstrings.md](cstrings.md) | C strings: `cstr`, literals, byte arrays, text on the stack, reading, walking, printing; `Bytes` and `String`, text on the heap, `$"..."` and `` $`...` `` |
| [ownership.md](ownership.md) | `Bytes`, `String`, `Array<T>` and `Dictionary<K, V>`, the owners on the heap, and the rules: freed by its block, moved by `return` and by passing, copied by `.copy()`, borrowed as a pointer; `uchr`, a codepoint |
| [structs.md](structs.md) | structs by their bare name, members, initializers, a struct with no tag `{x:f64, y:f64}`, methods, operators |
| [unions.md](unions.md) | unions, the same way, and `union{i:i32, f:f32}` with no tag |
| [enums.md](enums.md) | C's enums, and enums with values: `enum json { null; n: f64; s: String }`, a union that knows its case |
| [functions.md](functions.md) | `let f(...)`, function types, anonymous functions, overloading |
| [flow-controls.md](flow-controls.md) | `if`, `while`, `do`, `for`, ranges, `for x in s`, conditions are `bool` |
| [printing.md](printing.md) | `print`, `println`, template literals, `` $`...` `` a String from one |
| [properties.md](properties.md) | `.size`, `.count`, `.type`, `.typename`, `.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.addr`, `.isNull` |
| [modules.md](modules.md) | `#import` of Kelvin files, `modules/`, `modules/complex.k` |
| [c-interfaces.md](c-interfaces.md) | C headers, typedefs, C's functions, `libkelvin` from C, the C compiler |

## Reserved words

`print` and `println` belong to the prelude and cannot be redefined.
`String` is a type since #55; the method names `toString` and `fmt`
stay reserved (#22), as a value's text is `x.cstr`.
Kelvin reserves all of C's keywords, plus `i8` … `u128`, `f32`, `f64`,
`bool`, `true`, `false`, `String`, `Bytes`, `Array`, `Dictionary`, `uchr`, `any`, `nullptr` and `cstr`
*(provisional P11)*, `as` (#14), and `let` and `var` (#27). `in` is a
keyword only in `for i in ...` and in an anonymous function's
`{ (a:T) in ... }`, so C names called `in` still work. It
also rejects C compiler keywords beyond C11, such as `__extension__`,
`__real__`, `__alignof__`, `typeof`, `_BitInt`, `__signed__` and `__int128`
(use `i128`), because in C they can act as casts or prefix operators
*(provisional P20)*. Names starting with `_kv_` belong to the C that
kelvinc writes, and `kv_` and `KV_` ones to its runtime, so Kelvin cannot
declare them *(provisional P44)*. kelvinc names what it writes after the source,
as in `_kv_n_text` for the text buffer of `n.hex`, `_kv_i_count` for the
counter of `for i in`, and `_kv_main_fn` for an anonymous function in
`main`; a repeat gets 1, 2, ..., and with no name to derive from, a
number from 0, as in `_kv_text0` (#38). `__asm__(...)` and `__attribute__((...))` remain
usable, and `_Pragma("...")` works as a statement. `fn` is not reserved.

## Not available yet

These are C features without a Kelvin spelling so far:

- `typedef`
- an array of functions, or a pointer to a function type: `[(i64):i64](4)`
  has no spelling yet
- bit-fields
- unnamed parameters
- fallthrough between cases, and a case inside a statement of the
  switch (Duff's device): a case ends at the next (#63)
- nested or local struct/union/enum definitions; a struct, a union or an
  enum with values and no tag, `{x:f64, y:f64}`, `union{i:i32, f:f32}`,
  `enum{i:i32, f:f32}`, goes where a type goes instead (#59, #60, #61)
- `long double`
- string prefixes (`L"..."`)
- `inline`, `restrict`, `_Alignas`, `_Static_assert`, `_Generic`
- generics: a function over several types is written once per type, as
  `modules/complex.k` does for `complex32` and `complex64`; `Array<T>`
  and `Dictionary<K, V>` are the built-in generics (#57, #65)
- literal suffixes (on purpose: see [integers.md](integers.md))
- the preprocessor beyond `#import`
- statements of the form `name(x)` where `name` is a C typedef: C reads
  them as declarations, and Kelvin cannot tell (see [grammar.md](grammar.md))
- `alignof` and `typeof` (reserved C compiler keywords, P20; `v.type` is
  Kelvin's `typeof`, #34)
- `__asm__ __volatile__ (...)` (two names in a row; `__asm__(...)` works)
- `sizeof` of a typedef-based type with a suffix, such as `sizeof(FILE^)`
  (Kelvin reads `FILE^` as a dereference; `sizeof(size_t)` and `sizeof p`
  work)

## Diagnostics

The C compiler checks Kelvin programs, and `#line` directives make its
errors and warnings point at your `.k` file and line. Kelvin's own syntax
errors also carry hints for C habits, such as `*p`, `p->m`, `int x;`,
`long`, `10UL` or `(int)x`.
