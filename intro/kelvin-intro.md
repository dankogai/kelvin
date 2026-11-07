<!-- layout: title -->
# Kelvin

C, changed bit by bit.

A quiet alternative to C, still 100% ABI compatible.

<!-- notes: Kelvin is for people who already know C and like it. It is not a new language with a C interface. It is C, with changes made one at a time. -->

---

<!-- layout: flow -->
# Kelvin is C with different spelling

`kelvinc` translates Kelvin into C and hands that to your C compiler.

- **hello.k**: what you write
- **kelvinc**: checks what Kelvin adds
- **C source**: readable, with `#line` back to your `.k`
- **cc**: clang or gcc, as ever
- **hello**: an ordinary native program

Types, layout, calling conventions and semantics are C's by construction.

<!-- notes: There is no VM, no new backend and no runtime you did not ask for. kelvinc checks what Kelvin adds, such as owners, Optionals and Results. Everything else is left to the C compiler, whose diagnostics point at your .k file. -->

---

<!-- layout: scale -->
# The name is the design

> **Dan**: Let's start implementing kelvin. An attempt to implement a `better C`. It is virtually named by you:
> **Claude**: I'd call it **Kelvin**.
> C is also the symbol for Celsius, and Kelvin is its natural successor. The step size is identical, so everything you know about C carries over one-to-one…
> Kelvin wins because the pun is also a design spec.

Dialogue.md, sections 1 and 2. Runners-up: Sequel, P, Coda, Seam.

<!-- notes: Claude found the name, in a conversation before the project began, and Dan pasted that answer in to start it. One degree Celsius is one kelvin, so you do not relearn your step size. The part left out here promised to eliminate undefined behavior, and that did not survive the first day: as the next slides show, Kelvin keeps C's semantics, undefined behavior included. The pun stayed the design. -->

---

<!-- layout: compare -->
# Declarations read left to right

```c title="C"
#include <stdint.h>

struct point { int64_t x, y; };

int64_t add(int64_t a, int64_t b) {
    return a + b;
}

int main(void) {
    const int64_t k = 7;
    int32_t n = 0;
    int32_t *p = &n;
    *p = 9;
    return n;
}
```

```kelvin title="Kelvin"
struct point { x: i64; y: i64 }

let add(a:i64, b:i64):i64 {
    return a + b
}

let main():i32 {
    let k = 7
    var n:i32 = 0
    var p:i32^ := &n
    p^ = 9
    return n
}
```

<!-- notes: Types go after the name. Pointers are a postfix caret, so p^ is C's *p and p^.m is C's p->m. let never changes, var does. Types say their size. A struct is named by its bare name. Semicolons are optional. -->

---

<!-- layout: code -->
# C stays C

```kelvin title="fromc.k"
#import <stdio.h> as C    // C's own header

let square(n:i32):i32 { return n * n }

let main():i32 {
    let k = 7             // an i64, and a let
    var total:i32 = 0
    var p:i32^ := &total  // C's int32_t *
    p^ = square(3)
    printf("%d %lld\n", total, k)
    return 0
}
```

```text title="prints"
9 7
```

- **Headers** come in as they are
- **Precedence and conversions** are C's
- **Undefined behavior** stays, as written

<!-- notes: You import a C header and call it directly, with no bindings to write. Kelvin keeps C's precedence and conversions, and it does not hide undefined behavior behind traps. If you know what your C does, you know what this does. -->

---

<!-- layout: compare -->
# You can read the C it writes

```kelvin title="sum.k"
struct point { x: i64; y: i64 }

let sum(p:point):i64 {
    return p.x + p.y
}

let main():i32 {
    var total:i64 = 0
    for i in 0..<3 { total += i }
    return i32(total)
}
```

```c title="kelvinc --emit-c sum.k" emit
struct point
{
    int64_t x;
    int64_t y;
};
int64_t sum(const struct point p)
{
    return p.x + p.y;
}
```

A `let` parameter is simply `const`. A Kelvin struct is a C struct, and a Kelvin function a C function.

<!-- notes: kelvinc --emit-c prints what it generated, and it is C you could have written. A let parameter is simply const. That is what "100% ABI compatible" means here: a Kelvin struct is a C struct and a Kelvin function is a C function. -->

---

<!-- layout: why -->
# Why C, in 2026?

C lets you shoot your own foot, and Uncle Sam tells you to avoid it.

The case against, all of it true

Kelvin stands on C anyway

- **2024**: the White House asks for memory safe languages, and names C and C++ as lacking it
- **2025**: the NSA and CISA press the same case
- **Today**: Go, Rust and Swift are memory safe, and emit native binaries
- **1**: **libc**, or libSystem on macOS, is there to stay
- **2**: **The C compiler** is the most basic compiler infrastructure, on every platform we can think of
- **3**: **Standing on C** makes Kelvin more than ten times smaller
- **4**: **Memory safety** can be built within C's features, and can look like Rust or Swift

<!-- notes: Take the objection seriously, because it is right. The White House report is Back to the Building Blocks, February 2024. The NSA and CISA guide is Memory Safe Languages, June 2025. Their 2023 Case for Memory Safe Roadmaps lists Go, Rust and Swift among its examples. Kelvin's answer is not that C is safe. It is that C is the ground everything already stands on, so the cheapest place to add safety is on top of it. The next three slides take these in turn. -->

---

<!-- layout: code -->
# libc and cc are already there

```text title="otool -L of hello world, built on a Mac"
Kelvin  /usr/lib/libSystem.B.dylib

Rust    /usr/lib/libSystem.B.dylib

Go      /usr/lib/libSystem.B.dylib
        /usr/lib/libresolv.9.dylib

Swift   /usr/lib/libSystem.B.dylib
        /usr/lib/swift/libswiftCore.dylib
```

Go 1.12's release notes: "libSystem is now used when making syscalls on Darwin."

- **libc stays**: all four link it here, the memory safe three included
- **cc is everywhere**: the most basic compiler infrastructure, on every platform we can think of
- **So Kelvin reuses both**, and has neither to port

<!-- notes: Memory safe languages do not leave libc behind. Go used to call the kernel directly on macOS, and since Go 1.12 it goes through libSystem. On Linux the system call interface is stable, so Go and Rust's musl target can skip libc there, but the operating system's own interface is C nearly everywhere else. Each new platform is one that already has a C compiler, so Kelvin has no backend to write for it. -->

---

<!-- layout: sizes -->
# Standing on C keeps Kelvin small

More than ten times smaller, and more than half of it is Unicode data.

What is in Kelvin's 13.7 MB

Measured 2026-11-07 with `intro/measure.sh`, on each default branch. LLVM and the C compiler are counted for no one, and the others do far more.

| Project | Every tracked file, MB | The compiler's own source, MB |
|---|---|---|
| Kelvin | 13.7 | 1.2 |
| Go | 155.6 | 24.9 |
| Swift | 217.2 | 58.9 |
| Rust | 230.1 | 35.0 |

- **Unicode data**: 8.6
- **kelvinc**: 1.2
- **Everything else**: 3.9

<!-- notes: Tracked files means everything in the repository, tests and documents included: 11 to 17 times Kelvin's size. Leave out the 8.6 MB of Unicode Character Database files and Kelvin is 5.1 MB, so 30 to 45 times. The compiler alone is 21 to 49 times. Be fair about why. These projects have far larger libraries, their own backends or deep LLVM integration, Windows support, and many more years behind them. And Kelvin leans on a C compiler that is itself millions of lines. That is the point: it is already on your machine, and Kelvin need not carry it. -->

---

<!-- layout: compare -->
# Looks like Rust or Swift, transpiles to C

```kelvin title="safer.k"
let half(n:i64):i64? {
    if n % 2 != 0 { return none }
    return n / 2
}

let main():i32 {
    let s = $"owned"
    let h = half(7)
    println(s, " ", h)
    return 0
}
```

```c title="kelvinc --emit-c safer.k" emit
struct _kv_opt_i64 half(const int64_t n)
{
    if (n % 2 != 0)
    {
        return _kv__kv_opt_i64_make_none();
    }
    return _kv__kv_opt_i64_make_some(n / 2);
}

__attribute__((cleanup(kv_string_free)))
kv_string s = KV_STRING_LIT("owned");
const struct _kv_opt_i64 h = half(7);
```

Owners free themselves, `T?` must be unwrapped and `xs[i]` is checked, all in plain C. `^` pointers and C's undefined behavior stay, so Kelvin is safer C, without Rust's guarantee.

<!-- notes: The Optional is a C struct with a tag. The owner is C's cleanup attribute and a plain call. An index is an ordinary function that checks. The C compiler sees nothing new. Say the limit out loud: Kelvin does not prove memory safety as Rust does. A raw pointer can still dangle, as in C, and that is unmarked. What this shows is that these features need nothing C lacks. -->

---

<!-- layout: dollar -->
# One $, and both worlds coexist

C's own literals stay exactly as they are. A single `$` puts a flexible one beside each.

| C's own: rigid, memory unsafe | | With a $: flexible, memory safe | |
|---|---|---|---|
| "text" | a `cstr`: a bare pointer to fixed bytes | $"text" | a `String`: owns its bytes, grows |
| [1, 2, 3] | a fixed array: nothing checks `a[7]` | $[1, 2, 3] | an `Array`: grows, and `xs[7]` stops the program |
| {1, 2} | a struct's fields, in order | ${"ann": 31} | a `Dictionary`, and `${1, 2}` is a `Set` |
| // text | a comment: C has no such literal | $/k.l/i | a `RegExp`, its pattern checked as you compile |

Short of a pointer taken into one, with `:=`, the `$` side cannot be misused as C's can.

> "as a human I feel the need for the shortcut."

Dan, on the day $ arrived

```kelvin title="check: the slide's table compiles, and prints this"
#import <RegExp>
struct pair { a: i64; b: i64 }
let main():i32 {
    let t := "text"
    var a:[i32](3) = [1, 2, 3]
    let f:pair = {1, 2}
    var s = $"text"
    s += "!"
    var xs = $[1, 2, 3]
    xs += 4
    let d = ${"ann": 31}
    let u = ${1, 2}
    let re = $/k.l/i
    println(t, " ", a[1], " ", f, " ", s, " ", xs, " ", d, " ", u.count, " ", re.test($"Kelvin"))
    return 0
}
```

```text
text 2 {a: 1, b: 2} text! [1, 2, 3, 4] {"ann": 31} 2 true
```

<!-- notes: Dan counts this as his best invention in Kelvin. The problem: C's own arrays and strings had to stay, or it would not be C, yet String("...") was too long for anyone to want to write. One character solves it. Nothing about C's forms changed, so C code and C's habits keep working, and you say which world you mean at each literal. It carries over to types: $[i64] is an Array of i64, and ${String: i64} a Dictionary. The $/.../ needs #import <RegExp>; // was already a comment. The quote is Dan's, from Dialogue.md section 93, the day $ arrived. -->

---

<!-- layout: pointers -->
# Pointers got a little harder, on purpose

```c title="C: the classic, once admired"
#include <stdio.h>

int main(void) {
    char a[4] = "abc", b[4];
    char *p = b;
    const char *q = a;
    while ((*p++ = *q++) != '\0')
        ;
    puts(b);
    return 0;
}
```

```kelvin title="Kelvin: one step a line"
let main():i32 {
    var a:[u8](4) = "abc"
    var b:[u8](4)
    var p:u8^ := &b[0]      // := for a pointer
    var q:u8^ := &a[0]
    while q^ != 0 {
        p^ = q^
        p++                 // a statement
        q++
    }
    p^ = 0
    println(&b[0] as cstr)
    return 0
}
```

```text
abc
```

```kelvin-error given="var n:i32 = 0; var m:i32 = 1; var p:i32^ := &n; var q:i32^ := &m"
while (p++^ = q++^) != 0 { }
```

```text
'++' is a statement in Kelvin, not a value: step the pointer on a line of its own
```

```kelvin-error given="var n:i32 = 0; var m:i32 = 1; var p:i32^ := &n; var q:i32^ := &m"
p = q
```

```text
'p' is a reference (i32^): assign it with ':=', not '='
```

<!-- notes: (*p++ = *q++) != '\0' is not cool any more. The pointers are still there, with C's arithmetic and C's undefined behavior, so nothing is taken away. They are just a little more trouble to write, and that is the point. := makes every pointer assignment stand out, so it is the first place to look for a dangling one. Assignment and ++ are statements, so no line does three things at once. ++ works only on pointers, and on a number the error says to write += 1. And for text you would not write this loop at all: with a String it is s.copy(). -->

---

<!-- layout: code -->
# Owners free themselves

```kelvin title="owners.k"
let shout(name:cstr):String {
    var s = String(name)   // owns its bytes
    s += "!"
    return s               // moved to the caller
}

let main():i32 {
    let hi = shout("hello")
    var xs = $[3, 1, 2]    // an Array<i64>
    xs += 4
    println(hi, " ", xs, " ", xs.count)
    return 0
}                          // hi and xs freed here
```

```text title="prints"
hello! [3, 1, 2, 4] 4
```

- **A block frees** what its variables own
- **`return` and passing** move an owner
- **`=` never copies**: write `.copy()`, or borrow with `&`

<!-- notes: String, Bytes, Array, Dictionary, Set and Bits live on the heap. There is no garbage collector and no hidden copy. It compiles to C's cleanup attribute and plain calls. -->

---

<!-- layout: errors -->
# Mistakes are told in Kelvin's words

```kelvin-error
int x = 3
```

```text
'int' is not a Kelvin type; use i32 or u32
```

```kelvin-error
let n = 0
n += 1
```

```text
'n' is a let and cannot change; declare it with var
```

```kelvin-error
let a = $"x"
take(a)
println(a)
```

```text
'a' was moved out and holds nothing now: assign it anew before using it
```

```kelvin-error
let m:i32? = 3
println(m + 1)
```

```text
i32? has no operator '+': compare with == and !=
```

<!-- notes: kelvinc checks what Kelvin adds and says what is wrong, usually with the fix. It knows C habits too: writing int, *p, p->m or 10UL each gets a hint. Whatever is C's own, the C compiler checks. -->

---

<!-- layout: code -->
# Failure is a value

```kelvin title="result.k"
#import <stdio.h> as C
#import <errno.h> as C

let open(path:cstr):Result<FILE^, i32> {
    let f:FILE^ := fopen(path, "r")
    if f.isNull { return err(errno) }
    return f                        // a T becomes ok(T)
}

let check(path:cstr):Result<i64, i32> {
    let f := try open(path)         // an err goes up
    fclose(f)
    return 1
}

let main():i32 {
    println(check("/no/such/file"))
    let first:i64? = none
    println(first ?? 42)
    return 0
}
```

```text title="prints"
err(2)
42
```

- **`T?` and `Result<T, E>`** are C structs underneath
- **`try`** passes an error up
- **`??`** gives a fallback

<!-- notes: C hands back a value through a pointer and an error code beside it. Here a function returns both as one value. It wraps C's fopen and errno directly. The 2 is ENOENT. -->

---

<!-- layout: code -->
# Any type can grow methods and operators

```kelvin title="money.k"
struct money { cents: i64 }

extend money {
    static let +(a:Self, b:Self):Self { (Self){a.cents + b.cents} }
    static let <(a:Self, b:Self):bool { a.cents < b.cents }
    let dollars:f64 { .cents / 100.0 }
    let doubled():Self { self + self }
}

let main():i32 {
    let a:money = {150}
    let b:money = {275}
    var bills = $[b, a]
    bills.sort()              // by its own <
    println(bills)
    println((a + b).cents, " ", a.doubled().dollars)
    return 0
}
```

```text title="prints"
[{cents: 150}, {cents: 275}]
425 3.0
```

- **Methods and attributes** in `extend T { }`
- **Operators** are functions chosen by their types
- **In C** they are plain functions

<!-- notes: This is not C++. There are no classes, no inheritance and no vtables. A method is a C function with a name made of its type. The struct's layout does not change at all. -->

---

<!-- layout: code -->
# Collections and text are built in

```kelvin title="values.k"
struct point { x: i64; y: i64 }

let main():i32 {
    let squares = (1...5).map { $0 * $0 }
    let even = squares.filter { $0 % 2 == 0 }
    let ages = ${"ann": 31, "bob": 42}
    let name = $"ann"
    println(squares, " ", even)
    println(squares.sorted { $0 > $1 })
    println(ages)
    println((point){3, 4})
    println(`${name} is ${ages["ann"]!}`)
    return 0
}
```

```text title="prints"
[1, 4, 9, 16, 25] [4, 16]
[25, 16, 9, 4, 1]
{"ann": 31, "bob": 42}
{x: 3, y: 4}
ann is 31
```

- **`$[...]` and `${...}`** make Arrays, Dictionaries and Sets
- **`{ $0 * $0 }`** is an anonymous function, not a closure
- **`println`** shows any value

<!-- notes: These come from the prelude, with no import. C has no closures, so an anonymous function cannot use its surrounding function's variables, and kelvinc says so. print and println work on any value, structs included, with no format string. -->

---

<!-- layout: code -->
# async and await are threads

```kelvin title="tasks.k"
let count(lo:i64, hi:i64):i64 {
    var n:i64 = 0
    for i in lo..<hi { n += i % 3 == 0 ? 1 : 0 }
    return n
}
let label(n:i64):String { $`${n} of them` }

let main():i32 {
    var parts:$[Task<i64>] = $[]
    for q in 0..<4 {
        parts += async count(q * 1000, (q + 1) * 1000)
    }
    var total:i64 = 0
    for i in 0..<parts.count { total += await parts[i] }
    let text = await async label(total)
    println(text)
    return 0
}
```

```text title="prints"
1334 of them
```

- **`async f(x)`** runs `f` on a thread of its own
- **`await`** waits, and gives its value
- **An owner** moves back to the caller

<!-- notes: There is no event loop or colored scheduler. async f(x) starts a thread and gives you a Task right away. await joins it. It is what you would write with pthreads, with less to get wrong. -->

---

<!-- layout: compare -->
# C calls Kelvin too

```kelvin title="geo.k" lib=geo
struct point { x: f64; y: f64 }

let dist2(a:point, b:point):f64 {
    let dx:f64 = a.x - b.x
    let dy:f64 = a.y - b.y
    return dx * dx + dy * dy
}

// kelvinc --lib geo.k
// builds geo.kh, libkgeo.a and
// libkgeo.dylib or libkgeo.so
```

```c title="main.c" link=geo
#include <stdio.h>
struct point { double x, y; };
double dist2__point__point(struct point a,
                           struct point b);

int main(void) {
    struct point a = {0, 0}, b = {3, 4};
    printf("%.1f\n",
           dist2__point__point(a, b));
    return 0;
}
```

```text title="prints"
25.0
```

From Kelvin it is `#import <geo>`. From C it is a library like any other.

<!-- notes: A library built by kelvinc is C, so a C program links it directly. A module's functions are named by their parameter types, so that overloads can coexist, and --emit-c shows those names. The shared library needs libkelvin on the library path. From Kelvin it is just #import <geo>. -->

---

<!-- layout: cards -->
# A library, one import at a time

- **IO**: files, pipes and processes
- **OS and SYS**: directories, environment, processes
- **JSON**: `JSON.parse` and `JSON.stringify`, as JS has them
- **SION**: SION values, JSON with more
- **MsgPack**: MessagePack of a SION
- **RegExp**: `$/pattern/flags`, JS's regular expressions
- **UnicodeData**: normalization, graphemes, case mappings
- **math**: `math.h` for floats and complex numbers
- **Your own**: `kelvinc --lib M.k` builds one

Each comes in with `#import <M>`. What you do not import stays out.

<!-- notes: The core is C, the prelude is String, Array and friends, and everything else is an explicit import. Each document in documents/ says which of the three it describes. -->

---

<!-- layout: stats -->
# Made one agreed change at a time

- **472** numbered changes
- **1,205** tests, with clang and with gcc 15
- **9** CI jobs on macOS, Ubuntu and FreeBSD

> "Hey, you are going too fast!"

The first day's compiler added traps, slices and `defer` in one step. It was thrown away for bare C, and every departure since was proposed and agreed alone.

- **Design.md** records what was decided
- **Dialogue.md** records how, in the words used

<!-- notes: Kelvin was designed by Dan Kogai and written with Claude. The quote is from the first day, in Dialogue.md section 5. Since that reset, every change has a number, a row in Design.md and a section in Dialogue.md, so you can read why any feature exists. Test programs also run under ASan, and kelvinc and kc under ASan and UBSan. -->

---

<!-- layout: selfhost -->
# Kelvin is learning to compile itself

`kc` is a compiler written in Kelvin. It builds itself to a fixpoint, in CI on every push.

- **Today**: 176 of 354 test programs and examples
- **Next**: as capable as `kelvinc`
- **Then**: skip C, from `kc` to assembly or LLVM IR
- **Someday**: the whole backend in Kelvin

| Change | Programs kc builds, by numbered change |
|---|---|
| #466 | 147 |
| #469 | 148 |
| #470 | 153 |
| #471 | 162 |
| #472 | 176 |

<!-- notes: kc is experimental: about 22,000 lines of Kelvin, beside kelvinc's 24,000 lines of C. Stage two and stage three write the same C, about 30,000 lines. It may use libc, as C does, but no C of its own. Each program it builds must print what kelvinc's build prints. -->

---

<!-- layout: try -->
# Try it

```sh
git clone https://github.com/dankogai/kelvin
cd kelvin
make
./kelvinc --run examples/hello.k
./kelvinc --emit-c examples/hello.k
make install PREFIX=~/.local
```

- **Needs**: a C11 compiler, GNU make, Python 3
- **Runs on**: macOS, Linux, FreeBSD; not Windows
- **Status**: 0.1.0, so a later 0.x may change things
- **To read first**: `documents/versusC.md`
- **In VS Code**: `make vscode`
- **License**: MIT

<!-- notes: documents/versusC.md lists every difference from C at a glance. make test compiles the documents' examples, so they stay true. The first release was tagged in November 2026. -->

---

<!-- layout: closing -->
# Everything you know about C carries over

github.com/dankogai/kelvin

MIT License

<!-- notes: Thank you. Questions welcome. -->
