# Kelvin versus C

This is a reference for C programmers. It lists every way Kelvin differs
from C, as of the current compiler. Anything not listed here works exactly
as in C, including the semantics, the ABI, operator precedence, implicit
conversions and undefined behavior.

The table below is the whole language at a glance; the documents beside
this one have the details, one topic each.

Items marked *(provisional)* were chosen during implementation and have
not been agreed yet. See the P-numbers in [Design.md](../Design.md).

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
| `int64_t n; uint8_t b; double x;` | `var n:i64; var b:u8; var x:f64`, or by the full names, `int64`, `uint8`, `float64` (#151) |
| `float f = 1.5f;` | `var f:f32 = 1.5` |
| `1UL << 40` | `1:u64 << 40` |
| `uint16_t u = 0xdead;` | `var u = 0xdead:u16` (inferred as `u16`) |
| `const char *s;`, `char *s;` | `var s:cstr` (immutable text, #52), or `var s:u8^` for bytes to write |
| `int a[4];`, `int a[4] = {0};` | `var a:[i32](4)`, as C's, not filled; `var a = [i32](4)`, zero-filled (#49) |
| `int *a[4];` | `var a:[i32^](4)` |
| `int (*p)[4];` | `var p:[i32](4)^` |
| `const char *const s = t;` | `let s:const u8^ := t` |
| `long add(long a, long b) { ... }` | `let add(a:i64, b:i64):i64 { ... }` (parameters are lets) |
| `struct shape { struct size { double w, h; } s; };`, `struct size` a type of the file | `struct shape { struct size { w: f64; h: f64 }; s: size }`: `size` inside shape, `shape.size` outside, as in Swift (#389) |
| `int main(void) { struct pair { int a; } p = {1}; ... }`, a type of the block | `struct pair { a: i32 }` in the block, then `var p:pair = {1}`: the block's, `_kv_main_pair` in C (#391) |
| `static inline int sq(int x) { return x * x; }` | `inline let sq(x:i32):i32 { x * x }`: C's `static inline`, its body in a module's `.kh` too (#392) |
| `void copy(char *restrict d, const char *restrict s);` | `let copy(d:u8^ restrict, s:const u8^ restrict)`: after the `^`, as a pointer's own `const` (#393) |
| `_Static_assert(sizeof(long) == 8, "64 bits");` | `static_assert(sizeof(i64) == 8, "64 bits")`, C23's name, the message optional (#394) |
| `_Alignof(double)`, `alignof(double)` | `alignof(f64)`, C23's name; a value's is `x.align` (#395) |
| `_Alignas(16) unsigned char buf[64];` | `alignas(16) var buf:[u8](64)`, C23's name, before the declaration as `static` is (#396) |
| `T(x);`, C's declaration of `x` where `T` is a typedef | `x as T` converts; a statement `name(x)` of a name kelvinc does not see is `if (1) name(x);` in C, so a typedef there is C's error, not a declaration (#402) |
| `int (*ops[4])(int)`, `int (**out)(int)`, `typedef int (*op)(int);` | `var ops:[(i32):i32](4)`, `out:((i32):i32)^`, `typealias op = (i32):i32`; `Array<op>` and `Dictionary<String, op>` too (#403) |
| `void on_signal(int) { ... }`, a parameter unnamed | `let on_signal(_:i32) { ... }`: `_` may stand for several, and is never read (#388) |
| `void f(void);` | `let f()`, or `let f():()` with the result written out (#141); the two mean the same |
| `void *p = NULL;` | `var p:any^` (a reference is `nullptr` until assigned) |
| `(void *)0`, `NULL` | `nullptr` |
| `static int g(void);` | `static let g():i32`; `static let T.name(...)` is a function of the type, `T.name(...)` (#111) |
| functions taking `struct T *` and a global per type | `extend T { let f() { } let x:R { } var y:R { get { } set(v) { } } static var n:i64 = 0 }`, used as `v.f()`, `v.x`, `v.y = 1`, `T.n` (#130 to #133) |
| `"what??!"`, which C11 reads as `"what|"` (a trigraph) | `"what??!"`, as written: Kelvin has no trigraphs (#220) |
| `"line one\n" "line two\n"` | `"""`, the two lines, `"""`, each on its own line: the text as it is, no escapes (#115, #118) |
| a loop of `printf` to show an array or a struct | `println(xs)`, `println(p)`, `println(d)`: the value whole, `[1, 2]`, `{x: 1}`, `{"k": 1}`; `println(v.pretty)` indented (#123, #124) |
| a JSON library | `#import <JSON>`; `var j = JSON.parse(text)`, `j.object["k"].array[0].number`, `JSON.stringify(&j, "  ")` (#113) |
| a MessagePack library, and a text form of its values | `#import <SION>`, `SION.parse(text)`, `s["key"]`, `SION.stringify(&s, 2)` (#152); `#import <MsgPack>`, `MsgPack.pack(&s)`, `MsgPack.unpack(&b)` (#153) |
| ICU, for normalization and grapheme clusters | `#import <UnicodeData>`: `s.normalize(nfc)`, `s.graphemes`, `s.upper()`, `s.fold()`, `uchr("é").name`, `.category` (#156) |
| `regcomp`, `regexec`, POSIX's classes | `#import <RegExp>`: `let re = $/(\d+)-(?<m>\d\d)/g`, `re.test(&s)`, `s.match(&re)`, `s.replace(&re, "$<m>/$1")`, `s.split(&re)`, JS's syntax with `\p{...}` and `\X` (#157) |
| `int main(int argc, char **argv)` | `let main(argc:i32, argv:u8^^):i32` |
| `struct p { int x, y; };` | `struct p { x: i32, y: i32 }` |
| `struct p q;`, `typedef struct p p;` | `var q:p` (a tag is a type by its bare name, #29) |
| `struct { double x, y; } v = {3, 4};` | `var v:{x:f64, y:f64} = {3.0, 4.0}`: one type per spelling, so it passes to `let f(v:{x:f64, y:f64})` (#59) |
| `union { int i; float f; } u;` | `var u:union{i:i32, f:f32}` (#60) |
| `struct { uint8_t tag; union { double n; ... } u; } j;` and a `switch` on the tag by hand | `enum json { null; n: f64; s: String; a: Array<json> }`: `json.n(1.5)`, `j.is(n)`, `j.n` checked, `switch j { case n: ... }` (#61) |
| `switch (n) { case 1: case 2: ...; break; default: ... }` | `switch n { case 1, 2: ... default: ... }`: a case ends at the next, no fallthrough, every value handled (#63) |
| `case 1: ...; /* no break */ case 2: ...` | `case 1: ...; fallthrough` then `case 2: ...`: Swift's, on into the next case's body (#386) |
| `struct s { unsigned ready : 1, busy : 1; };`, `s.ready = 1` | `struct s { flags: Bits }` and `enum flag { ready, busy }`: `s.flags[ready] = true`, `s.flags[busy] = !!n` (#387) |
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
| `#include "x.h"` and a separately compiled `x.c` | `#import "x.k"`, `#import <math>` (#40, #46) |
| `x.h` and `libx.a`, built by `cc -c x.c` and `ar rcs`, linked with `-lx` | `kelvinc --lib x.k` builds `x.kh` and `libkx.a` into `modules/`, which `#import <x>` brings in and links by itself (#143, #146) |
| `csin(z)` beside `sin(x)` | `let sin(z:c64):c64 { ... }` beside C's `sin` (#41) |
| `cadd(a, b)` | `a + b`, given `let +(a:c64, b:c64):c64 { ... }` (#42) |
| `double complex z = 1.0 + 2.0 * I;` | `let z:c64 = c64(1.0, 2.0)` (modules/math.k, #43) |
| `sizeof(long)` | `sizeof(i64)` |
| `#include <stdio.h>` | `#import <stdio.h> as C` |
| C in the same file | `#inline C { ... }` (#197) |
| `printf("%" PRId64 "\n", n)` | `println(n)` (prelude, no import) |
| `snprintf(buf, sizeof buf, "%lld", n)` | `n.cstr` (`cstr` text on the stack) |
| `strlen(s)` | `s.count` (measured once per scope, #52) |
| `char *buf = malloc(n); ... free(buf);` | `var b = Bytes(n)`, freed when its block ends (#54) |
| a UTF-8 string by hand | `var s = String("héllo")`, or `$"héllo"`, `for c in s { }` by codepoint, `s.count` (#55, #62) |
| `uint32_t cp`, encoded by hand to print | `uchr`: `print(c)` shows the character, `c.utf32` the number (#56) |
| undefined behavior past a bound, or `assert` and `abort()` | a check that fails at run time prints its reason and exits with status 1, `kelvin: index 3 is out of range: the Bytes has 3`; `KELVIN_ABORT=1` in the environment makes it abort instead, for a debugger (#174) |
| `T *xs = malloc(n * sizeof *xs); ... realloc ...` | `var xs = Array([1, 2, 3])`, or `$[1, 2, 3]`, `xs += x`, `xs[i]` checked, freed by its block; the type is `Array<i64>`, or `$[i64]` (#57, #58, #62, #64) |
| a hash table by hand, or a library's | `var d = ${"ann": 31}`, `d["bob"] = 42`, `d["ann"]` checked, `d.has(k)`, `d.find(k)`, `for k, v in d`, `d.keys`, `d.values`; the type is `Dictionary<String, i64>`, or `${String: i64}` (#65, #66) |
| a hash set by hand | `var s = ${3, 1, 4}`, `s += 9`, `s.has(4)`, `s | t`, `s & t`, `s ~ t`, `for x in s`; the type is `Set<i64>`, or `${i64}` (#71, #73) |
| a sentinel such as `-1` or `NULL`, or a `bool` beside the value | `i64?`: `none` or `some(3)`, `x.some` checked, `x ?? 0`, `x.is(none)`, `x == none`, `x == 3`, `x.map { $0 > 2 }`, `if let v = x { }`, `switch x { case some: ... case none: ... }` (#72, #74, #79, #80) |
| an error code beside the value, or `errno` | `Result<i64, String>`: `ok(v)` or `err(e)`, `r.ok` checked, `r ?? 0`, `if let v = r { } else { r.err }` (#75), `if let err(e) = r { }` (#78), `r == 42`, `r == err(2)` (#79), `r.map(f)`, `r.mapErr(g)`, `r.flatMap(f)` (#80, #81); `let v = try f()` passes the `err` up (#76) |
| `FILE *f = fopen(p, "r"); if (!f) ...; ... fclose(f);` | `let f = IO(p, "r")`, straight, `f.error` the errno when it did not open (#109), closed when its block ends; `for line in f.lines { }`, `for chunk in f.read(4096) { }`, `let s = f.string` (a String straight, #107), `f.write("x")`, `f.path`, `f.stat.size` (a `Stat` straight, #104), `f.listdir` (an Array straight, #101, #106), `IO.stderr.println("n = ", n)`, `f.seek(n)`, `f.position`, `f.eof`, `i64(line)` of a line read, `IO(fd, "r")`, `f.fd`, `IO.popen("ls", "r")`, `IO.exec(["ls", "-l"], "r")`, `IO.exec(args, "r", dir, ["LC_ALL=C"])`, `IO.exec(args, "r", "", env, true)`, `p.status`, `p.signal`, `p.kill(15)`, `IO.pipe()` (#82, #83, #84, #85, #86, #87, #89, #90, #91, #92) |
| `getcwd`, `getenv`, `stat`, `opendir` and `readdir`, `system`, `exit` | `OS.cwd`, `OS.env("HOME")`, `OS.isdir(p)`, `OS.listdir(p)`, `OS.stat(p).ok.size`, `OS.walk(dir)`, `OS.glob("*.k")`, `OS.mkstemp("x")`, `OS.touch(p)`, `OS.chown(p, uid, gid)`, `OS.username(uid)`, `OS.strerror(e)`, `OS.uname`, `OS.normpath(p)`, `OS.urandom(16)`, `OS.realpath(p)`, `OS.join(a, b)`, `OS.time`, `OS.system(cmd)`, `SYS.exit(1)`, `SYS.argv`, `SYS.platform` (#94, #95) |
| `return (struct point){0, 0};` | `return {0, 0}`: the list takes the result type, a Result's or Optional's value wrapped (#77) |
| `memcpy` of a part, with its length by hand | `xs[1..<3]`, `s[2...]`, `b[..<4]`: a slice, a copy, checked (#68) |
| `snprintf` into a buffer sized by hand, or `asprintf` | `` var s = $`${name}: ${n}` ``, a String with no bound (#67) |
| `realloc`, `strcat` | `b += "more"`, `b.append(x)`, `b.insert(i, x)`, `b.remove(i, n)` |
| `sizeof x` | `x.size` |
| `__typeof__(x) y;`, C23's `typeof(x) y;` | `var y:typeof(x)`, as C's, a `let`'s `const` too (#398), or `var y:x.type`, without it (#34) |
| `snprintf(buf, sizeof buf, "0x%x", n)`, `n` unsigned | `n.hex` (`u8^` text on the stack; a signed `n` gives `+0x2a` or `-0x2a`) |
| `double area(struct shape s)` | `let shape.area():f64 { ... self ... }`, called as `s.area()` |
| `int (*cmp)(const void *, const void *);` | `var cmp:(const any^, const any^):i32` (#31) |
| a `static` function written only to be passed | `sort(xs, n) { $0 < $1 }` (an anonymous function, #32) |

## Where each thing lives

Each document says so under its title. In short:

| Home | What | Needs |
|---|---|---|
| the core | numbers, `bool`, pointers, `cstr`, fixed arrays, structs, unions, enums, functions, operators, the statements, `#import` | kelvinc alone: the C is C's own, nothing linked |
| the prelude | `print`, `println`, templates, the text of properties, `Bytes`, `String`, `uchr`, `Array<T>`, `Dictionary<K, V>`, `Set<T>`, the checks of `T?`, `Result<T, U>` and enums with values | `kelvin_prelude.h` and `libkelvin`, which every program gets without an import |
| loaded explicitly | `IO`; `OS` and `SYS`; `c64` and `c32`; `JSON`; a C header's names | `#import <IO>`, `#import <OS>` (#144, #145), a header and a library each; `#import <math>`, `#import <JSON>`, sources; `#import <x.h> as C` |

## The documents

| Document | Covers |
|----------|--------|
| [grammar.md](grammar.md) | declarations, type inference, quoting text (`"..."`, `` `...` ``, `"""..."""`, `$"..."`), expressions, lines and `;`, assignment as a statement, C habits kelvinc catches |
| [operators.md](operators.md) | every operator, C's precedence, what moved: `^`, `~`, `&`, `as`, `:=`, `p++`, ranges |
| [integers.md](integers.md) | `i8`…`u128`, their literals, conversions of any number, numbers from text |
| [floatingpoint.md](floatingpoint.md) | `f32`, `f64`, their literals, reading, printing and text, C's complex types |
| [bool.md](bool.md) | `bool`, `true` and `false`, where a `bool` comes from, conditions, converting |
| [bits.md](bits.md) | `Bits`, 64 bits in a `u64`, `bv[n]` a `bool`, `.flip(n)`, the bitwise operators, `!!n` (#387) |
| [pointers.md](pointers.md) | `T^`, `:=` for references, `any^`, `nullptr`, `.next`, `.prev`, `.isNull` |
| [results.md](results.md) | `Result<T, U>`: `ok` and `err`, `??`, `if let`, `try`, switching on it; `T?` as its special case |
| [optionals.md](optionals.md) | `T?`, the Result whose `err` carries nothing: `none`, `some`, `??`, `if let` |
| [json.md](json.md) | `#import <JSON>`: `JSON` as an enum with values, `JSON.parse(text)`, `JSON.stringify(&j, replacer, space)` as JS's (#113) |
| [sion.md](sion.md) | `#import <SION>`: SION values, JSON with more, keyed by any value, `SION.parse`, `SION.stringify`, `s["key"]` (#152) |
| [msgpack.md](msgpack.md) | `#import <MsgPack>`: `MsgPack.pack(&s)` and `MsgPack.unpack(&b)` of a `SION` (#153) |
| [unicodedata.md](unicodedata.md) | `#import <UnicodeData>`: `s.normalize(nfc)`, `s.graphemes`, the case mappings, a `uchr`'s `.name`, `.category`, `.combining` and decompositions (#156) |
| [regexp.md](regexp.md) | `#import <RegExp>`: `$/pattern/flags`, JS's regular expressions over Strings, `test`, `exec`, `match`, `replace`, `split`, `\p{...}`, `\X` (#157) |
| [io.md](io.md) | `IO`: files and the standard streams as owners, `IO(path, mode)` straight with `f.error`, `.bytes`, `.string`, `.read(n)`, `.lines`, `.write` |
| [os.md](os.md) | `OS`: the working directory, the environment, files and directories, a shell command, the pid |
| [sys.md](sys.md) | `SYS`: the arguments, the platform, exiting |
| [tasks.md](tasks.md) | `async f(x)` and `await`: a call on a thread of its own, a `Task<R>` of its result (#312) |
| [sets.md](sets.md) | `Set<T>`, `${T}`: elements, `has`, `insert`, the set algebra, walking |
| [ranges.md](ranges.md) | `Range<T>`: `a..<b`, `a...b`, `a...`, `..<b`, `...b`, a Sequence of integers, `map`, `filter`, `reduce`, `flatMap`, `lazy`, `prefix` (#373) |
| [iterators.md](iterators.md) | `Iterator<T>`, a state and a function; `var T.next():E?`, Sequences' `makeIterator()`, `for x in it`, and `map`, `filter`, `reduce` and `flatMap` of one |
| [dictionaries.md](dictionaries.md) | `Dictionary<K, V>`, `${K: V}`: entries, lookup, `keys` and `values`, walking |
| [arrays.md](arrays.md) | `[T]` and `[T](N)`, `[...]` initializers, `.count`, `[T](n)`, arrays and pointers; `Array<T>`, `$[T]`, the growable one on the heap |
| [strings.md](strings.md) | strings: `cstr`, literals, byte arrays, text on the stack, reading, walking, printing; `String`, text on the heap, `$"..."` and `` $`...` `` |
| [bytes.md](bytes.md) | `Bytes`, any bytes on the heap: `Bytes("text")`, `Bytes([...])`, `Bytes.fromBase64`, `b[i]`, `b += x`, `b.string()`, `b.escape()`, with a RegExp (#54, #172) |
| [ownership.md](ownership.md) | `Bytes`, `String`, `Array<T>` and `Dictionary<K, V>`, the owners on the heap, and the rules: freed by its block, moved by `return` and by passing, copied by `.copy()`, borrowed as a pointer; `uchr`, a codepoint |
| [structs.md](structs.md) | structs by their bare name, members, initializers, a struct with no tag `{x:f64, y:f64}`, methods, operators |
| [unions.md](unions.md) | unions, the same way, and `union{i:i32, f:f32}` with no tag |
| [enums.md](enums.md) | C's enums, and enums with values: `enum json { null; n: f64; s: String }`, a union that knows its case |
| [functions.md](functions.md) | `let f(...)`, function types, anonymous functions, overloading |
| [flow-controls.md](flow-controls.md) | `if`, `while`, `do`, `for`, ranges, `for x in s`, conditions are `bool` |
| [printing.md](printing.md) | `print`, `println`, template literals, `` $`...` `` a String from one |
| [properties.md](properties.md) | `.size`, `.count`, `.type`, `.typename`, `.cstr`, `.dec`, `.hex`, `.oct`, `.bin`, `.addr`, `.isNull` |
| [modules.md](modules.md) | `#import` of Kelvin files, `modules/`, `modules/math.k`, a module as `M.kh` and `libkM`, `kelvinc --lib` |
| [c-interfaces.md](c-interfaces.md) | C headers, typedefs, C's functions, `libkelvin` from C, the C compiler |
| [c-contract.md](c-contract.md) | the C a program becomes: the file, the build, types, owners, names, main (#208) |

## Reserved words

- `print` and `println` belong to the prelude and cannot be redefined.
- `String` is a type since #55; the method names `toString` and `fmt`
  stay reserved (#22), as a value's text is `x.cstr`.
- Kelvin reserves all of C's keywords, plus `i8` … `u128`, `f32`,
  `f64`, `bool`, `true`, `false`, `String`, `Bytes`, `Array`,
  `Dictionary`, `Set`, `Optional`, `Result`, `uchr`, `any`, `nullptr`
  and `cstr` *(provisional P11)*, `as` (#14), `let` and `var`
  (#27), `fallthrough` (#386), `Bits` (#387), `static_assert`
  (#394), `alignof` (#395), `alignas` (#396) and `typeof` (#398).
  - `in` is a keyword only in `for i in ...` and in an anonymous
    function's `{ (a:T) in ... }`, so C names called `in` still work.
- It also rejects C compiler keywords beyond C11, such as
  `__extension__`, `__real__`, `__alignof__`, `__typeof__`, `_BitInt`,
  `__signed__` and `__int128` (use `i128`), because in C they can act
  as casts or prefix operators *(provisional P20)*.
- Names starting with `_kv_` belong to the C that kelvinc writes, and
  `kv_` and `KV_` ones to its runtime, so Kelvin cannot declare them
  *(provisional P44)*.
  - Nor can it read a `_kv_` name (#388), such as `_kv_arg0`, an
    unnamed parameter's.
  - kelvinc names what it writes after the source, as in `_kv_n_text`
    for the text buffer of `n.hex`, `_kv_i_count` for the counter of
    `for i in`, and `_kv_main_fn` for an anonymous function in `main`.
  - A repeat gets 1, 2, ..., and with no name to derive from, a number
    from 0, as in `_kv_text0` (#38).
- `__attribute__((...))` remains usable, and `_Pragma("...")` works as
  a statement. `fn` is not reserved.

## Not available yet

These are C features without a Kelvin spelling so far: none, as of
#403. Each C feature Kelvin lacks is left out on purpose, below.

## Left out on purpose

These C features stay out, as decided (#294):

- **`typedef`**: Kelvin names a type anew with `typealias A = T`
  (#149), so a `typedef` is an error that says so (#294).
- **`long double`**: its meaning is the platform's, and aarch64 has no
  binary128 in hardware.
  - `f128` stays on the wishlist until that is resolved.
- **String prefixes** (`L"..."`, `u8"..."`): a Kelvin source is always
  UTF-8, valid and without a BOM.
  - The one prefix is `$"..."`, a String.
  - A prefix, a BOM and a byte that is no UTF-8 are errors (#295).
- **Deep generics**: generics stay shallow on purpose.
  - The built-in containers are generic, `Array<T>`,
    `Dictionary<K, V>`, `Set<T>` (#57, #65, #71), as they cannot be
    written otherwise.
  - A function over several types is written once per type, as
    `modules/math.k` does for `c32` and `c64`; `Complex` is not
    generic, as there are only its two.
  - Generics in full need type constraints, as Swift's protocols are,
    which also make generics harder to use and to build; they wait for
    a neat way to constrain types.
- **Literal suffixes**: see [integers.md](integers.md).
- **Assembly** (#399), `__asm__ __volatile__ (...)`, `__asm__` and
  `asm(...)`: GNU C's extension, which clang follows, no part of the C
  standard.
  - It is C's, so it goes in `#inline C { __asm__ __volatile__("nop"); }`,
    among a function's statements or at the top level.
  - Written in Kelvin, it is an error that says so, and `__volatile__`
    one that names `volatile`; `asm` stays a name of the program's.
- **`sizeof(FILE^)`**, a C header's type with a suffix (#400): kelvinc
  reads no header, so it cannot tell a header's type, `FILE`, from its
  value, `stdout`, and takes `FILE^` for a dereference, as `stdout^`
  is: C then refuses `sizeof(*FILE)`.
  - Every object pointer has one size, so `sizeof(any^)` is the size of
    any, and `f.size` that of a variable's.
  - `sizeof(FILE)` and `sizeof(size_t)` are C's, as written.
- **Duff's device** (#401), a case inside a statement of the switch, a
  jump into a loop's middle: a sleight of hand of 1983, which `cc -O2`
  does better now, unrolling the loop itself.
  - A case is written at the top of the switch's block (#63), as in
    Swift; one inside an `if` or a loop is an error.
  - What it does is written with `fallthrough` (#386): the remainder by
    a cascade of cases, then whole blocks in a loop; see
    [flow-controls.md](flow-controls.md).
- **`_Generic`** (#397): a function of one name already takes several
  types, by its overloads, `let f(x:i64)` and `let f(x:f64)` (#41), and
  so do methods, operators and the built-in properties.
  - kelvinc chooses the overload where it sees the arguments' types,
    and writes C's `_Generic` itself where only C sees them, so a
    program never needs to.
  - Written, it is an error that says so.
- **Bit-fields**: `unsigned a : 1` packs as the platform's ABI decides.
  - A struct holds a `Bits` (#387) instead, 64 bits in a `u64`, each a
    `bool` by its place, and an enum names the flags: `s.flags[busy]`.
  - See [bits.md](bits.md).
- **The preprocessor**: Kelvin's directives, `#import` and
  `#inline C { ... }`, are its only ones.
  - `#inline C { ... }` holds no C preprocessor directive, and no
    Kelvin directive nests in it.
  - Either is an error that says so (#296).

## Diagnostics

The C compiler checks Kelvin programs, and `#line` directives make its
errors and warnings point at your `.k` file and line. Kelvin's own syntax
errors also carry hints for C habits, such as `*p`, `p->m`, `int x;`,
`long`, `10UL` or `(int)x`.

- **A value of the wrong type** is Kelvin's error, in Kelvin's words,
  where C would refuse it or convert it silently (#255): `'n' is an
  i64, and this is text`.
  - Checked: a declaration, `var n:i64 = v`; an assignment, `n = v`,
    `p.x = v`; an entry, `d[k] = v` (#246); what `contains` looks for
    (#248); what `??` falls back to (#250); an element of an Array, in
    a typed `$[...]`, by `xs[i] = v`, and by `append`, `+=` and
    `insert` (#256), `an element of Array<i64> is an i64, and this is
    text`; an argument of a Kelvin function or method (#257), `'x' of
    'half' is an f64, and this is text`.
  - A number takes any number, as C converts it; a String a String or
    text; a `cstr` text; an Optional its `T` or `none`; a pointer any
    pointer; anything else its own type.
  - Left to C: a C typedef, as `size_t`; a value only C sees; a
    function, which is matched by its overloads first.
