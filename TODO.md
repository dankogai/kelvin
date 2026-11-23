# TODO

What is left, checked against the code after #675; done since #657: the
crash of a struct that holds itself (#659); and the wrong message of a
cstr's byte set, which was none: `let s = "abc"` is the error there, as
text is declared with `:=`, and `s[0] = 65` of `let s := "abc"` says a
cstr is immutable (#660); a constant index past a fixed array's end,
kelvinc's error (#661); an integer divided by a constant 0, kelvinc's
error (#662); a literal that does not fit its type, kelvinc's error
(#663); a constant shift past its type's width, kelvinc's error (#665);
the reviews of P662 to P714 (#664, #666, #670, #673 to #675, #679, #691, #709); and a member of arithmetic
whose type is C's, `(n + 1).foo` of a `u8`, which is kelvinc's `i32 has
no member 'foo'`, where it was C's error (#669); and an integer literal
past u64's greatest, or past i64's in a declaration with no type,
kelvinc's error (#678); and kc's top-level let of a pointer, a const
pointer as kelvinc writes it, `const uint8_t *const p`, where kc wrote
`const const uint8_t *` and `const int64_t *`, which C refused `q^ = 5`
of (#680). Added since #657, each
leaving every program as it was: `#import <Prime>`, with a computed
attribute of an integer type (#668); `_` among a literal's digits
(#671); and `BigInt.generatePrime(bits)` (#672). Each item becomes a
numbered change of Design.md when it is ordered; this list says what is
known, not what is planned.

## Versions

- So long as the grammar and the semantics stay the same, the version
  stays 0.4.x.
  - A fix, an error in Kelvin's words where C's came, a document, and
    kc reading more of what kelvinc reads are 0.4.x.
  - An addition that leaves every program as it was is 0.4.x too, as
    the user chose for an integer type's computed attribute (#668) and
    for `_` among a literal's digits (#671).
  - A change of what a program means, or of what it must write, is
    0.5.0.
- Release chores are done only when ordered.
  - The CHANGELOG entry, from #651 on: #651 to #721 so far.
  - The version: kelvinc's KELVIN_VERSION and the VS Code package's.
  - The README's line of the release notes.
  - The tag and the release.

## Faults in kelvinc

- None known: an integer literal past u64's greatest is kelvinc's error,
  and so is one past i64's in a declaration with no type (#678), found
  while literals.md was written (#677).
- A member of arithmetic, `(n + 1).foo`, is kelvinc's error (#669).
- The sweep's three that C only warned of are kelvinc's errors (#661 to
  #663), and so is a constant shift past its width (#665).

## kc

- kc says each of the 1039 programs kelvinc refuses in kelvinc's words:
  the 990 of #652 to #656, and those of #659 to #678, #702 and #705
  alike.
- kc places each of those errors at kelvinc's line and column, matched
  in batches as the user ordered after #680 (#681 to #689), and
  selfhost/errors.sh compares them (#690), but one, listed in
  selfhost/errors.txt as `place`: anon_list_c_arg, {'a', 'b', 'c'}
  given to a C function, which kelvinc says at its second comma, where
  its parse of an anonymous function ends.
- kc prints a struct's members of no printer of their own by their text,
  a pointer, a function, an IO, a plain enum and a C header's type, as
  kelvinc's (#692), where it said "not yet what this holds".
- kc shows a fixed array in a template and by `.pretty`, and a let
  parameter's by its count as declared, a parameter's `[T]` by its
  address, as kelvinc's (#693).
- kc reads a top-level enum with no name whose cases have values, its
  spelling's type, its cases words of the program (#120), and the
  methods of a type with no tag (#121), as kelvinc's (#694).
- kc reads overloads of a variadic function, `f__T__va`, chosen as
  kelvinc chooses, C's choice falling back to the one whose `...` takes
  the value (#695).
- kc reads `typeof` of an expression and `x.type` where `x`'s type is
  inferred or only C sees, written `__typeof__(x)` as kelvinc writes it,
  and `(T){...}` of such a type (#696).
- kc reads a function defined inside a function, `_kv_outer_name` in C,
  its block's, as kelvinc's #180 (#697).
- kc walks a pointer up to a 0, from nowhere none, and what only C sees
  so, as kelvinc's #30 and #610, and takes nowhere among a `[cstr]`'s
  elements (#698).
- kc reads `[T?](n)`, a fixed array of Optionals, and prints a fixed
  array of a count C computes, `[f64](n)`, as kelvinc's (#699).
- kc gives a global C cannot initialize its value at its first use, once,
  by `pthread_once`, as kelvinc's #493, so a value's text is made in a
  global's initializer too (#700).
- kc reads `T^ atomic`, the pointer itself C's `_Atomic`, `T *_Atomic`,
  as kelvinc's #642 (#701).
- An enum, a struct or a union with no name in a block or inside a type
  is kelvinc's error, which kc says in its words where it said "not
  yet" or its own, with two tests of tests/error (#702).
- kc reads a parameter's array of arrays whose inner count C computes,
  `m:[[i64](n)](2)`, as kelvinc's (#703).
- kc takes none and a value some(v) is made of among a fixed array of
  Optionals' elements, `([i64?](2))[none, 1]`, as kelvinc's (#704).
- A Dictionary's key, a Set's element and a fixed array where an
  element goes are checked where the type is written, kelvinc's errors
  at its place, where kc built `Set<f64>` and said the rest at the
  variable, with three tests of tests/error (#705).
- kc prints a choice of bools, `a < b ? a > 0 : b > 9`, as a bool,
  where C's ?: of them gave an int, 1 (#706).
- kc writes a record's text as kelvinc's, `_kv_T_cstr` to its own
  longest, for `.cstr` and a template, an Array member `[...]` (#707).
- kc keeps a let's const in `typeof(k)`, `const i64`, as kelvinc's
  (#708).
- kc reads `x as T ? a : b` as a choice, as kelvinc's, where it read
  `T?`, and holds `&$"b"` given to a search, so that SION.k and the
  tests that import it build (#710).
- kc reads `Optional<T>()` and `Optional<T>(v)`, a typed none and
  some(v), and moves an owner into a `T?` parameter as some of it, as
  kelvinc's (#711).
- kc makes an Optional's and a Result's `.map`, `.flatMap` and
  `.mapErr`, as kelvinc's #80 and #81 (#712).
- kc makes a Bytes's `.toBase64()`, `Bytes.fromBase64(text)`, its slice
  `b[lo..<hi]` and `b + c`, as kelvinc's (#713).
- kc takes an empty last case, `default:`, `p[i] = v` through a let
  pointer parameter, `IO.strerror(code)` and `(shape){.rect = ...}` of
  an enum with values, as kelvinc's (#714).
- kc reads an operator at a line's end, `$"a" "b"`, labels and goto,
  `[[2] = 9]`, `(T){` in a condition as kelvinc tells it, a comma in a
  condition, a method's prototype and `var a = 1, b = 2` of globals, as
  kelvinc's (#715).
- kc appends to an Array `&ys`'s elements, an Array an expression gives,
  what `&p` points to and text as a String, and reads `xs.capacity`, as
  kelvinc's (#716).
- kc reads `let s:[u8] = "hi"`, `[[T]]` of rows, `let ap := arr` of an
  array and infers C's `size_t` from sizeof, `.size`, `.align` and a
  count, as kelvinc's (#717).
- kc reads `v.pretty(n)`, `cstr restrict`, `$(...)` in a function of a
  type and an anonymous function's `:()`, as kelvinc's (#718).
- kc reads a list of initializers that hold functions, `$(...)` in an
  anonymous function, a `?:` across lines and `f as (i64) : g`, a call
  in a top-level struct's count and an anonymous function's array
  parameters, as kelvinc's (#719).
- kc reads `((i64):i64)^`, arrays of functions, a file imported again
  by another path, a header next to an imported file and `{.s = v}`
  where a variable `s` hides the case, as kelvinc's (#720).
- kc reads `.pretty` of an enum with values, `async` of a function
  value and a number's text in a brace-less for body, as kelvinc's
  (#721).
- Found while #717 was made, not changed:
  - kc writes a let's local array without C's `const`, `int32_t a[2]`,
    where kelvinc writes `const int32_t a[2]`; kc's own checks keep it
    read-only, and what is printed is the same.
  - `let xs:Array<i64> = [1]` is kelvinc's error `'[...]' initializes
    an array, and this is Array<i64>: write a value`, and kc's `an
    array is not a value here: ...`; no test of tests/error has it.
- Places where kc reads not yet what kelvinc reads, 29 as counted after
  #675, ordered taught in batches after #691:
  - `(T?){}`, which kelvinc builds as `some(0)`, a zeroed C struct whose
    tag 0 is `some`, and kc refuses: kelvinc's to settle first, as it
    is no meaning to copy; a fixed array in another type is kelvinc's
    error too, said alike since #705;
  - the number of a prelude enum's word that only C gives, which no
    enum of the prelude has, so no program reaches it.
- kc's output that differed from kelvinc's, found while #692 to #696
  were made, is kelvinc's, the user's order after #705 (#706 to #708).
- kc builds and prints what kelvinc's prints of 474 of the 506 programs
  of tests/run and examples, the quines as run.sh compares them, as of
  #721; 30 of the rest need C headers, #inline C or a JS module. Those
  that stop on errors of kc's own, which the user ordered taught in
  batches after #709, by kind, 2 left:
  - owners in function values: anon_owner_result, method_overload;
- Self-hosting's mid goal, no C emission, has no number yet.

## Provisional rows

- P715 to P726, the details of #710 to #721, until reviewed; the reviews confirmed
  every row to P714, and a review's own detail row is confirmed by that
  review (#675).

## Open design

- Closures and protocols: neither is in 0.4.0, and protocols come first
  when one is taken up.
- `long double` and `f128` have no Kelvin spelling yet.
- Safe primes of `<Prime>`, a prime p with (p - 1) / 2 prime, as
  OpenSSL's `BN_generate_prime_ex` makes with `safe`: not now, as the
  user answered for #672.
