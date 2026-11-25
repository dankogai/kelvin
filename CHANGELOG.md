# Changelog

## 0.4.1 (#750)

The grammar and what a correct program means are 0.4.0's: `_` among a
literal's digits and `<Prime>` are added; more of C's errors, of its
warnings and of the programs that ran wrong are Kelvin's own errors;
and kc builds every program kelvinc builds, and says each of kelvinc's
errors in its words at its place: #651 to #749.

### The language

- **`_` among a numeric literal's digits** is left out (#671)
  ([literals.md](documents/literals.md)), as Swift and Perl have it:
  `1_000_000`, `0x7fff_ffff`, `0b1010_1010`, of every base and of a
  float's fraction and exponent.
- **A computed attribute of an integer type** (#668): `static let
  i64.answer:i64 { 42 }` is read as `i64.answer`, where it was an
  error.
- **`{}` of an Optional is `none`** (#725)
  ([optionals.md](documents/optionals.md)), as a `T?` declared with no
  value is: `var x:i64? = {}`, where it was `some(0)`.
- **A value read through const is a value** (#738, #746)
  ([pointers.md](documents/pointers.md)): `var y = p^` of a
  `p:const i64^` is a plain `i64`, which changes, and `$[p^]` an
  `Array<i64>`, where the variable and the Array's elements were const
  themselves, and C refused the change or warned.
- **`T^ const`** is a pointer that is itself const, C's `T *const`
  (#742): `var q:i64^ const := &v` changes what it points to,
  `q^ += 1`, and points nowhere else.
- **`.typename` names a count C computes as written** (#747)
  ([properties.md](documents/properties.md)): `[i32](n)` of a
  `var a:[i32](n)`, where it was `?`.
- A global used before it is written takes the types it names with it
  (#734), and a compound literal goes where a macro's argument goes,
  `println(([i32](3))[1, 2, 3][1])` (#732).

### The library

- **`#import <Prime>`** (#668, #672) ([prime.md](documents/prime.md)),
  of each integer type and of `BigInt`:
  - `n.isPrime`, `n.nextPrime`, `n.prevPrime`, a `T?`,
    `n.isProbablePrime` and `n.isSurelyPrime`; `N.primes`, an
    `Iterator<N>` of the type's primes, 54 of `u8.primes`;
  - `BigInt.generatePrime(bits)`, a random prime of exactly that many
    bits, as OpenSSL makes one.

### Kelvin's errors where C's came

Each was C's error or warning, or a program that ran; each is kelvinc's
now, and kc's in the same words.

- A struct, a union or an enum with values that holds itself by value,
  where kelvinc ended with a segmentation fault (#659).
- A constant index outside a fixed array (#661); an integer divided by
  a constant 0 (#662); a literal that does not fit its type,
  `let c:u8 = 300` (#663); a shift by a constant count at or past the
  width (#665); an integer literal past u64's greatest (#678).
- A member of arithmetic whose type is C's, `(n + 1).foo` (#669).
- What const keeps from changing: an element of a `[const T](N)` and
  `p[i] = v` through a `const T^` (#733), and `q := &y` of a
  `q:i64^ const` (#742).
- A call through a function value of another count of arguments than
  its type has parameters (#740).
- A struct's member given a value of another kind, `{1, "two"}` of two
  numbers, and a number where an array member goes, which C took
  (#741).
- `ok({})` and `err({})`, a list that is no value (#743).
- A value where a function type goes that is no function of that type:
  `num({ (x:f64):i64 in 1 })` is `this is (f64):i64, where (i64):i64
  goes`, and so is text there, which C took with a warning (#748).

### Documents

- [literals.md](documents/literals.md) puts each literal beside its
  counterpart (#677).
- [TODO.md](TODO.md) is what is left, checked against the code, with
  the rule of the versions: the version stays 0.4.x so long as the
  grammar and the semantics stay the same (#658).
- The decisions made during implementation, P645 to P750, are reviewed
  and confirmed, in sixteen batches (#651 to #745).

### kc

- kc says each of the 1076 programs kelvinc refuses in kelvinc's words
  (#652 to #656), at kelvinc's line and column but one (#681 to #690),
  which `selfhost/errors.sh` compares.
- kc builds every program of tests/run and examples, 519, each printing
  what kelvinc's prints (#692 to #730), `#inline C` passed through
  (#727).
- It does the same of each change above.

## 0.4.0 (#650)

C's last features written in Kelvin, `thread_local`, `atomic` and
`#if os(...)`; `<Combinatorics>` and `gather`; a `$` that reaches every
literal inside it; and Kelvin's own errors where C's came before, kc
saying kelvinc's words: #609 to #649.

### The language

- **The `$` of `$[...]` and `${...}` reaches every literal inside it**
  (#616) ([arrays.md](documents/arrays.md)): `$["a", "b"]` is an
  `Array<String>`, where it was an `Array<cstr>`, and
  `${"k": ["v"]}` a `Dictionary<String, Array<String>>`.
  - A type written wins: `var cs:$[cstr] = $["x"]` is of cstrs.
  - `$""` is the type `String` wherever a type goes, `var s:$""`.
- **Used before written:** a struct, a union, an enum and its words, a
  typealias and a global, at the top level, as a function is since
  #505 and as in Swift (#626).
- **Every path of a function with a result returns a value** (#625)
  ([functions.md](documents/functions.md)): one that can reach the end
  of its body is an error, where it was C's warning and the program
  ran.
  - A function of no result that never returns is C's `noreturn`, so
    `_Noreturn` needs no word (#640).
- **A number prefers a parameter of its own kind** (#632):
  `twice(small)` of an `i32` calls `twice(n:i64)` over
  `twice(x:f64)`, where it was an error asking for a conversion.
- **`thread_local var x`** is each thread's own, C's `_Thread_local`,
  at the top level and, static, in a block (#641)
  ([tasks.md](documents/tasks.md)).
- **`atomic`** is C's `_Atomic`, a qualifier as `const` is, of a
  number, a bool or a pointer: `var hits:atomic i64 = 0`, and
  `hits += 1` from eight Tasks loses none (#642).
- **`#if os(macOS)`, `#elseif`, `#else` and `#endif`**, Swift's
  conditional compilation, choose code by the platform (#643, #644)
  ([versusC.md](documents/versusC.md)).
  - A condition is `os(name)`, joined by `!`, `&&` and `||`; a branch
    not taken is read as text alone.
  - `#define` stays left out.
- **Left out on purpose:** `register`, an error that says so (#640);
  the text prefixes `L"..."`, `u8"..."`, `u"..."` and `U"..."`, as
  #295 had them.
- An enum's word is of its enum to `.typename`: `red.typename` is
  `color`, where it was `i32` (#622).

### The library

- **`#import <Combinatorics>`** (#614, #615)
  ([combinatorics.md](documents/combinatorics.md)), as
  js-combinatorics and swift-combinatorics are:
  - `Permutation`, `Combination`, `PowerSet`, `BaseN`,
    `CartesianProduct`, `UniquePermutation`, `Permutations` and
    `Combinations`, each of indices, a `$[i64]`;
  - `x.count` a `BigInt`, which any count fits, `Permutation(3).count`
    `6n`; `x[i]` of an `i64` or a `BigInt`, `for ix in x`, and
    `x.sample()`;
  - `factorial`, `permutation`, `combination`, `factoradic` and
    `combinadic`.
- **`xs.gather(ix)`** of every Array, and **`s.gather(ix)`** of a
  String, the elements or graphemes at the indices of a `$[i64]` or an
  `[i64](N)` (#617, #618): `$"kelvin".gather(Permutation(6)[719])` is
  `nivlek`.
- A `BigFloat`'s range is of its leading bit, where it was of its last:
  2^(2^63) and more is an infinity at any precision, and bits below the
  least number are rounded off as an `f64`'s subnormals are (#623).

### Kelvin's errors where C's came

Each was C's error or warning, or a program that ran; each is kelvinc's
now, and kc's in the same words.

- A call of a variable that is no function, and one that hides a
  function of its name, `let sqrt = 2.0; sqrt(sqrt)` (#620).
- `self` in a function with no receiver, or in a global's value
  (#621).
- A call with another count of arguments than the function takes; a
  `return` of a value of another type; `p^` of what is no pointer; a
  comma in a built-in type's subscript, `a[0, 1]` (#627).
- A name declared twice in one block (#628).
- Two definitions of one name at the top level, whatever their kinds:
  two functions of the same parameters, two types, an enumerator and a
  function, a member twice (#646).
- A value past a struct's last member or an array's count, which C only
  warned of and dropped: `[i64](3) holds 3 elements, and this gives 4`
  (#647).
- A fixed array set whole, `a = b` or `a = [3, 4]` (#648).
- `break` in no loop and no switch, and `continue` in no loop (#649).
- The error of a C directive names `#if os(...)` among Kelvin's own
  (#645).
- An undeclared name stays C's to report.

### Documents

- [gotcha.md](documents/gotcha.md) says what Kelvin is not, for one who
  comes from Swift, JavaScript or Python, and what to write instead: no
  closures, no generics or protocols of a program's own, no classes,
  no exceptions (#619).
- [ownership.md](documents/ownership.md) says what owns by its name, a
  capital first letter, and names the prelude's owners in a table
  (#613).
- The decisions made during implementation, P1 to P644, are reviewed:
  639 confirmed, as later numbers amend them, and 5 retired (#633 to
  #639); the open questions Q5, Q10, Q12 and Q14 are answered (#632).

### kc

- `selfhost/errors.sh` runs kc over the programs kelvinc refuses, in
  the battery and in CI, against a list that only shrinks (#609).
- kc says kelvinc's errors where it built a program kelvinc refuses
  (#611), left one to the C compiler (#612), ended itself (#610, #624)
  or said its own words (#629 to #631): of 431 programs listed, 30 are
  left, each in kc's own words.
- It does the same of each change above.

## 0.3.0 (#608)

math and `UnicodeData` in the prelude, beside `RegExp` and `BigInt`,
with `Kelvin.name` to reach the prelude past a program's own names; a
String of graphemes; and the numbers of any size, `<Rational>` and
`<BigNum>`: #515 to #607.

### The prelude

- **math** needs no import (#591) ([math.md](documents/math.md)):
  `sin(0.5)`, `2.0.sqrt()`, `f64.tau` and `c64(1.0, 2.0) * 1.0.i`.
  - libkelvin holds it; a program that names none of its names compiles
    as before, and `#import <math>` still builds.
  - `abs(-3)` of an integer is Kelvin's, an `i64`.
- **`UnicodeData`** is in every program (#520)
  ([unicodedata.md](documents/unicodedata.md)).
- **`Kelvin.name`** is the prelude's `name`, whatever the program calls
  its own, as `Swift.print` is Swift's (#600)
  ([namespace.md](documents/namespace.md)): `Kelvin.log(x)`,
  `Kelvin.BigInt`, `Kelvin.nfc`.
  - A function of the program's with the name and the types of one of
    the prelude's is another function, and a type of its own with the
    name of one of the prelude's another type (#600).
  - A variable or an enum's word of the program's top level hides the
    prelude's of that name: `let exp = 2.5`, `let nfc = 5` (#604).
  - An operator of the prelude's own types is the prelude's alone:
    `let +(a:c64, b:c64):c64` is an error (#606).
  - `Kelvin` is no name of a program's own; `kelvin` is free.
- A module of the prelude that an import writes is read first, wherever
  the import stands (#601).

### Strings

- **A String's elements are its graphemes**, each a String, as Swift's
  (#522) ([strings.md](documents/strings.md)): `for c in s`, `s[i]`,
  the slices, `s.count`, `s.find` and `s.prefix` count them, and
  RegExp's offsets are of graphemes.
- **`s.codepoints`** is its codepoints, an `Array<u32>`;
  `for c in s.codepoints` walks the String in place (#521, #527).
- **`grapheme(c0, c1, ...)`** and
  **`String.fromCodepoints(c0, c1, ...)`** make a String of
  codepoints, each a `Result<String, CodepointError>` (#526).
- **`uchr` is no more**: a codepoint is a `u32`, and the word is an
  error that says what to write (#527, #528).
- C's text has a document of its own, [cstr.md](documents/cstr.md)
  (#525).

### Numbers

- **`x.bits`** of an integer and of a `BigInt` (#530, #531)
  ([bits.md](documents/bits.md)): its bits, an `Array<bool>`, place 0
  first; `x.bits[n]` is read and set where it is, and `T(bools)` is the
  way back.
  - `Bits`, the type, is no more (#532).
- **Of a number's type:** `T.min` and `T.max` of an integer type
  (#545); Swift's constants of a floating-point type, `f64.infinity`,
  `f64.nan`, `f64.pi`, `f64.ulpOfOne` and the rest (#546), and
  `f64.zero` (#596); `T.random()` of the number types and of `bool`
  (#547).
- **A floating-point number is
  `sign * significand * 2 ** exponent`**, three integers (#597, #598)
  ([floatingpoint.md](documents/floatingpoint.md)):
  - `x.sign` is -1 or 1, an `i64`, where it was a `bool?`;
  - `x.exponent` and `x.significand` are the power of 2 and an odd
    integer, `1.5` is 3 times `2^-1`, where they were IEEE 754's raw
    fields;
  - `f64(sign, exponent, significand)` makes the number of the three.
- **Text that pastes back:**
  - `x.dec` of a float is what print shows, after its sign, `+2.0`
    (#558);
  - `x.hex` of a float is Kelvin's own text on every system: an
    exponent of 0 has no sign, `+0x1p0`, and a subnormal is written by
    its first 1, `+0x1p-1074` (#603, #607);
  - `0o52` is an octal number, the text `n.oct` writes, and `0o17n` a
    `BigInt` (#561);
  - a complex number prints as `(1.5-2.0.i)`, has `z.hex` and `z.dec`,
    and is read from its text, `c64(text)` (#559, #569, #570);
  - an enum with values prints as it is written, `num.n(1.5)` (#529).
- `+x` of a struct is its value where the type has a unary `-`: `+1n`
  (#563).

### The library

- **`#import <Rational>`**, rational numbers (#538 to #540)
  ([rational.md](documents/rational.md)):
  - `rat64`, `rat32`, `rat16` and `rat8`, of two signed integers, and
    `BigRat`, of two `BigInt`s, which every result fits (#566);
  - `1.over(3)` is `(1/3)`; `+ - * /` and the comparisons, exact; an
    infinity, `(1/0)`, and a NaN, `(0/0)`, which what does not fit is;
  - read from its text, exactly: `rat64("8/-12")` is `(-2/3)` and
    `rat64("0.1")` `(1/10)` (#565, #567, #568).
- **`#import <BigNum>`**, the numbers of any size (#590)
  ([bignum.md](documents/bignum.md)):
  - `BigFloat`, a float of any precision, each result rounded to
    `BigFloat.precision` significant bits, 128 (#576, #577)
    ([bigfloat.md](documents/bigfloat.md));
  - `CBR` and `CBF`, complex numbers of two `BigRat`s and of two
    `BigFloat`s (#552, #581);
  - math's functions of each, `sqrt(BigFloat(2))` and
    `exp(CBF(0, 1))`, a `BigRat`'s to a precision (#553, #554, #580,
    #582), of numbers far from 1 too (#583 to #589).
- `F.zero`, `F.infinity`, `F.nan` and
  `F(sign, exponent, significand)` are of every one of them, as of an
  `f64` (#596, #598).
- Both are libraries built once, as `<JSON>` is: a program that imports
  `<BigNum>` builds in a quarter of a second, where it took four
  (#599).
- **An overlay**, as Swift's cross-import overlay: where `<A>` and
  `<B>` are both imported, `A+B` is imported too (#551, #579)
  ([modules.md](documents/modules.md)).
- **`BigInt`** is faster than Python's integers, and than those of a
  Ruby without GMP, in each case of
  [benchmarks/bigint](benchmarks/bigint/README.md) (#517 to #519).

### The language

- **A moved owner is dead on the path that moved it** (#605)
  ([ownership.md](documents/ownership.md)): `if c { return s }` and
  then `return s` builds, and so does a move in each branch of an `if`
  or in each case of a `switch`.
- **A type attribute may be computed**, `static let T.x:R { ... }`,
  read as `T.x` (#595).
- **Used before written**, as a function is (#505): a built-in type's
  method (#543), and an attribute and its setter (#544).
- **A value of a type's own**, `bool.random()` or `f64.pi * 2.0`, may
  begin a statement (#549), stand in parentheses (#545) and begin the
  else of `c ? a : b` (#578); an attribute of an `i64` is read on a
  literal, `7.half` (#548).
- A function may be named by its types as a member of a type is:
  `meters(x:f64)` beside the attribute `meters.f64` (#575).

### Fixes

- Kelvin errors in words where C's came before: an assignment to what
  is no place, `f() = 2` (#534); `&` of what has no address (#535); a
  call of an overload with no result where a value is asked (#593).
- A `)` or a `]` too many is said where it is (#555).
- A rational's infinity divided by a negative number is the other
  infinity (#574); a `CBR` by a real one, or times it, keeps a part
  that is 0 (#571 to #573).

### kc

- kc, the compiler in Kelvin, reads the prelude's modules and links
  libkelvin (#515), and `#import <M>` of any module (#516): it builds
  programs of `BigInt`, `RegExp`, math, `<Rational>` and `<BigNum>`
  (#542, #550), and does the same of each change above.
- It reads more of kelvinc's Kelvin: typed loops of every kind (#523,
  #524), `v.T` as `T(v)` (#533), `&f` and an overload chosen by a
  function's type (#536, #537), hex floats (#556), fixed arrays of
  pointers (#557), the prefix `+` (#560, #564) and `0o52` (#562).
- It says kelvinc's errors where it built the program or ended: a
  method's value dropped at a body's end (#594), `.x` and `self` where
  there is no self (#602).

## 0.2.0 (#514)

`RegExp` and `BigInt` in the prelude, as JS and Swift have `RegExp` and
Python and Ruby integers of any size, with the language changes they
asked for: #497 to #513.

### The prelude

- **`RegExp`** needs no import: a program that names it, or writes a
  `$/.../` literal, has it, with `Match` and `BytesMatch`;
  `#import <RegExp>` still builds (#504)
  ([regexp.md](documents/regexp.md)).
  - libkelvin holds RegExp, UnicodeData and the Unicode tables, built
    by `kelvinc --prelude`; a program that uses none of them links none
    of them, from the static libkelvin.a. `#import <UnicodeData>` stays.
- **`BigInt`**, integers of any size, written in Kelvin after
  swift-bignum, two's complement in u64 limbs (#507)
  ([bigint.md](documents/bigint.md)):
  - literals `123n`, `0xffn`, `0b101n`, as JS's (#508);
  - `+ - * / %` truncated as Kelvin's integers, comparisons,
    `& | ~ << >>`, an `i64` on either side (#507);
  - `b ** e`, Python's `pow(b, e, m)` as a function and a method,
    `a.gcd(b)`, `a.lcm(b)`, `a.isqrt()`, Karatsuba's multiplication past
    40 limbs (#511);
  - its text is its literal everywhere, `123n`, which reads back;
    `b.hex`, `b.oct`, `b.bin` are `+0xffn`, `-0o17n`, `+0b101n` (#509);
    `b.text(base)` the bare digits;
  - `i64(b)`, `u64(b)`, `f64(b)`, the nearest value, as `b.i64` and the
    rest (#512, #513); `b.exactI64` and `b.exactU64`, an `i64?` and a
    `u64?` (#511);
  - division by zero ends the program in words, as a failed check does.

### The language

- **`T(v)` is always a converter, never C's cast** (#513): of a number,
  the nearest value `T` holds, `u8(300)` is 255, `i64(1e30)` i64's
  largest, NaN 0; of a pointer that is no text, an error. `v as T`
  stays C's, which wraps.
  - Of a struct, a converter is its attribute of that name, `i64(b)` is
    `b.i64` (#512).
- **Called before written** (#505): a function, a method, an operator or
  a function of a type may be used before its definition, as in Swift;
  kelvinc writes its prototype, and every overload is seen.
- **Owners:**
  - an operator is lent its owner operands, which its caller keeps: `a *
    a + b` leaves `a` and `b` (#501);
  - so is a parameter written `b:lent T` (#510);
  - a local owner named in a struct's literal moves into it,
    `(Big){r, false}` (#503);
  - an owner that moves out in an expression is named nowhere else in
    it: `f(s, s)` and `s.count + f(s)` are errors in words, where C's
    order of evaluation decided (#500); `==` wraps a copy (#500).
- **Operators:** a struct defines `& | ~ << >>` and unary `~` (#502).
- **A type's own text** of any length, `let T.string:String { ... }`,
  which print shows whole (#506).
- **An attribute may be named as a converter**, `let i64:i64 { }` (#507).

### Fixes

- Kelvin errors in words where C's came before: a member a type does not
  have (#497); a converter of a struct, or of a pointer (#512, #513).
- An array of empty structs counts by its declared length, where it was
  0 / 0 (#499).
- A clean build of libkelvin, which CI found, after #504.

### kc

- kc, the compiler in Kelvin, does the same of each change but the
  prelude's modules, which it does not link; it zeroes an empty struct
  by `{}` (#498), and refuses a `123n` literal in words.

## 0.1.1 (#496)

`fetch()` and `localStorage`, JS's, as modules, with fixes found on the
way: #468 to #495.

### The library

- **`#import <fetch>`**, JS's `fetch()`, an HTTP/1.1 client of its own,
  HTTPS by OpenSSL ([fetch.md](documents/fetch.md)):
  - `fetch(url)` and `fetch(url, init)` give a
    `Result<Response, Error>` (#482, #483);
  - `RequestInit`: method, headers, body, redirect, `timeout` in `f64`
    seconds, `signal` from an `AbortController`, `stream`, `cookies`
    (#483, #486 to #489);
  - `res.text()`, `res.json()` (#484), `res.stream`, an `IO`, for a
    body that streams (#488);
  - a `CookieJar` kept across fetches and redirects, saved and loaded
    as curl's cookies.txt (#489, #490);
  - `make HAS_SSL=0` builds it without HTTPS; CI builds it with HTTPS
    on macOS, Ubuntu and FreeBSD.
- **`#import <localStorage>`**, JS's: the global `localStorage`,
  `getItem`, `setItem`, `removeItem`, `clear`, `length`, `key(i)`, kept
  in a JSON file of the program's (#491)
  ([localstorage.md](documents/localstorage.md)).
- **JSON** is built as a library, `JSON.kh` and `libkJSON`, which a
  module may import (#484).

### The language

- **A global** C cannot initialize, one that owns or of a value that is
  not a constant, is given its value at its first use, once, on any
  thread: `var names = $["a"]`, `let start = OS.time` (#493).
- **Printing** pastes back: a `uchr` inside a value is `uchr("é")`
  (#479), a fixed array `[a, b]` (#481).
- **`uchr`**: a walk of uchrs stops at `uchr(0)`, and `for n:u32 in s`
  gives each codepoint's number (#480); `uchr(s)` is the first codepoint
  of a String or a Bytes (#494).
- **An enum's value** is C's int to an integer's methods, `.bit(n)`,
  `.abs` and the rest (#469).
- **`i64(&s)`** of a String or a Bytes by reference reads its text, as
  `i64(s)` does (#495).

### Fixes

- Kelvin errors in words where C's came before: `x as uchr` (#468), an
  enumerator changed (#469), `uchr(2.5)` and `uchr(true)` (#494), an
  overload declared after a call that needs it (#492).
- An owner moves into a setter or a subscript's index, where it was
  freed twice (#474); a global owner assigned anew frees what it held
  (#493); `i64(&s)` gave the pointer's address (#495).
- tests/run.sh reads an error test's text byte by byte, under any
  locale (#485).

### kc

- kc, the compiler in Kelvin, reads more of kelvinc's Kelvin: trailing
  functions, a struct's operators, every integer type, attributes,
  subscripts, types with no tag, an enum's tag, `uchr` (#470 to #478),
  and the fixes above.

## 0.1.0 (#467)

The first release of Kelvin: C, changed bit by bit, still 100% ABI
compatible. `kelvinc` translates Kelvin into C and hands it to the C
compiler. The changes from C, 469 of them so far, are in
[README.md](README.md#changes-from-c) by topic, and the reasons for each
in [Design.md](Design.md) and [Dialogue.md](Dialogue.md).

### The language

- **Declarations** read left to right: `let k = 42`, `var n:i32 = 0`,
  `let add(a:i64, b:i64):i64`; `let` never changes; types say their
  size, `i8` to `u128`, `f32`, `f64`, `bool` built in.
- **Pointers** are `T^`, `p^` and `p^.m`; `nowhere` is null; `cstr` is
  immutable text; `p.next`, `p.addr`, `p.isNull`.
- **Types**: structs, unions and enums by their bare name, methods on
  any type, `extend T { }` with attributes, operators and subscripts;
  enums with values, `T?` and `Result<T, E>`, with `??`, `!`, `?.`,
  `if let` and `try`.
- **Functions**: function types `(T):R`, anonymous functions with
  `$0`, trailing ones, overloads beside C's.
- **Owners on the heap**, freed when their block ends, moved by
  `return`: `String`, `Bytes`, `Array<T>` (`$[...]`),
  `Dictionary<K, V>` and `Set<T>` (`${...}`), `Bits`, with `map`,
  `filter`, `reduce`, `sorted`, `join` and the rest. See
  [ownership.md](documents/ownership.md).
- **Text**: `print` and `println` of any value, template literals
  `` `n = ${n}` ``, `x.cstr` of any value, numbers read from text,
  `"""` blocks.
- **Ranges and iterators**: `0..<n`, `1...n`, `for x in seq`, lazy
  sequences, `Iterator<T>`.
- **Threads**: `async f(x)` and `await`, a `Task<T>`.
- **C stays C**: `#import <stdio.h> as C`, `#inline C { }`, C's
  precedence, conversions and undefined behavior, as written.

### The library

- **Modules**, each `#import <M>`: `IO` (files, pipes and processes),
  `OS` and `SYS`, `JSON`, `SION`, `MsgPack`, `RegExp` (`$/.../`),
  `UnicodeData`, `math`.
- **Your own modules**: `kelvinc --lib M.k` builds `M.kh` and `libkM`,
  which C can call too.

### Tools

- `kelvinc`: `--run`, `-c`, `--emit-c`, `--lib`, `-O`, `-g`; see
  `kelvinc --help`. `#line` directives point the C compiler's
  diagnostics at the `.k` source.
- `make install PREFIX=...` installs `bin/kelvinc` and
  `lib/kelvin/modules`; kelvinc finds its modules from there.
- VS Code: `make vscode` installs a grammar of Kelvin's own
  (`editors/vscode`).

### Platforms

- Tested in CI on macOS (clang), Ubuntu (clang and gcc) and FreeBSD
  (clang); kelvinc and kc themselves under ASan and UBSan, and the test
  programs under ASan.
- Needs a C11 compiler, GNU make and Python 3 to build; node, zip and
  unzip are optional.
- Windows is not supported.

### Stability

- 0.x is initial development: a later 0.x may change what 0.1.0 has.
- The provisional decisions, the P rows of Design.md and the documents'
  *(provisional Pn)* marks, and Design.md's open questions are deferred
  past 0.1.0, and may change before 1.0.
- kc, Kelvin's compiler written in Kelvin (`selfhost/`), is a preview:
  it builds itself to a fixpoint, in CI, and builds 148 of the 353
  test programs and examples; see [selfhost/README.md](selfhost/README.md).
