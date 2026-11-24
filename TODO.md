# TODO

What is left, checked against the code after #675; done since #657: the
crash of a struct that holds itself (#659); and the wrong message of a
cstr's byte set, which was none: `let s = "abc"` is the error there, as
text is declared with `:=`, and `s[0] = 65` of `let s := "abc"` says a
cstr is immutable (#660); a constant index past a fixed array's end,
kelvinc's error (#661); an integer divided by a constant 0, kelvinc's
error (#662); a literal that does not fit its type, kelvinc's error
(#663); a constant shift past its type's width, kelvinc's error (#665);
the reviews of P662 to P740 (#664, #666, #670, #673 to #675, #679, #691, #709, #723, #731, #735); and a member of arithmetic
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
  - The CHANGELOG entry, from #651 on: #651 to #735 so far.
  - The version: kelvinc's KELVIN_VERSION and the VS Code package's.
  - The README's line of the release notes.
  - The tag and the release.

## Faults in kelvinc

- The user's order after #731, the three faults of kelvinc's found
  while #724 to #730 were made, one number each, pushed when clean:
  - a compound literal's commas where a macro's argument goes,
    `println(sizeof ([i32](3))[1, 2, 3])`, which was C's error of
    kelvinc's C, and of kc's: the argument in parentheses (#732);
  - an element changed through a `[const i64](3)^`, C's error of
    kelvinc's C, and with it every element of a `[const T](N)` and
    `p[i] = v` through a `const T^`: errors in Kelvin's words (#733);
  - a global whose value needs a struct written after a function that
    names the global: the struct is moved up with the global (#734).
  With it the three are done.
- None known: an integer literal past u64's greatest is kelvinc's error,
  and so is one past i64's in a declaration with no type (#678), found
  while literals.md was written (#677).
- A member of arithmetic, `(n + 1).foo`, is kelvinc's error (#669).
- The sweep's three that C only warned of are kelvinc's errors (#661 to
  #663), and so is a constant shift past its width (#665).

## kc

- kc says each of the 1048 programs kelvinc refuses in kelvinc's words:
  the 990 of #652 to #656, and those of #659 to #678, #702, #705, #724,
  #725, #727 and #733 alike.
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
- kc writes a let's local array with C's `const`, `const int32_t
  a[2]`, and says a list where no array is declared in kelvinc's words,
  `'[...]' initializes an array, and this is Array<i64>: write a
  value`, the two differences found while #717 was made (#724).
- Found while #724 was made, not changed:
  - `var o:i64? = [i64](3)` is kelvinc's `case 'some' of i64? holds an
    i64, and this is i64^`, and kc's `... and this is [i64](3)`.
  - `var p:i64^ := [i64](3)`, zeros where a pointer goes, is kelvinc's
    zeroed compound literal, `(int64_t [3]){0}`, and kc's error.
  - A type name that is not known, `let j:JSON = [1]` with no import,
    is kelvinc's `unknown type name 'JSON'`; kc leaves it to C.
- Places where kc reads not yet what kelvinc reads, 29 as counted after
  #675, ordered taught in batches after #691:
  - `(T?){}`, which kelvinc built as `some(0)` and kc refused, is none
    in both, the user's answer after #723 (#725); a fixed array in
    another type is kelvinc's error too, said alike since #705;
  - the number of a prelude enum's word that only C gives, which no
    enum of the prelude has, so no program reaches it.
- kc's output that differed from kelvinc's, found while #692 to #696
  were made, is kelvinc's, the user's order after #705 (#706 to #708).
- kc takes and gives owners through function values, as kelvinc's
  (#722).
- kc builds and prints what kelvinc's prints of all 511 programs of
  tests/run and examples, the quines as run.sh compares them, as of
  #734.
  The 49 that stopped on errors of kc's own, which the user ordered
  taught in batches after #709, are taught, #710 to #722.
- Found while #725 was made, not changed:
  - Braces assigned to a member, an element or through a pointer,
    `p.x = {1}`, `a[0] = {3}`, `h^ = {3, 4}`, are kelvinc's `a list is
    not a value here: ...`, and C's error of kc's C.
  - `ok({1, 2})` where a `Result<pt, i64>` goes is kelvinc's error, and
    kc's ok of the struct.
- Found while #726 was made, not changed:
  - `r[1][2] = 5` through a `[const i64](3)^` was C's error of
    kelvinc's C, and kc's `this changes an element of a [const
    i64](3)`: kelvinc's words too since #733.
  - A pointer to an array of a count C computes, `[i64](n)^`, is
    kelvinc's, and kc's `not yet`.
  - `q[1].typename` through a `const i64^` is kelvinc's `const i64`,
    and kc's `i64`; a cstr's `s[1]` likewise, `const u8`.
  - A method a fixed array has not, `r[1].sum()`, is kelvinc's
    `[i64](3) has no member 'sum'`, and kc's `this method is not
    known`.
- Found while #733 was made, not changed:
  - `[const cstr](2)` is named `[cstr const](2)` by kelvinc's
    `.typename` and `[const cstr](2)` by kc's.
  - A pointer to a const pointer is `const i64^ const^` in kelvinc's
    words and `const const i64^^` in kc's.
  - `var c:[i64](2)` with no value is not zeroed by kelvinc, and is by
    kc.
- Found while #730 was made, not changed:
  - A number where a struct's array member goes, `{1, [7, 8, 9], 5}`
    of a `name:[u8](8)`, is left to C by kelvinc, which builds it, and
    kc's `an array is not copied by '='`.
  - Text longer than a struct's `[u8](N)` member is C's in both: the
    member filled, with no NUL.
  - A function's parameter of a function type whose own parameter's
    inner array counts by another parameter, `f:([[i64](n)](2)):i64`,
    is built by kelvinc; kc writes `n` into the type's typedef, C's
    error.
- Found while #729 was made, not changed:
  - `v()` of a `v:(i32, ...):i64`, fewer arguments than its
    parameters, is C's error of kelvinc's C, and kc's `this function,
    of type (i32, ...):i64, takes 1 argument, and it is given 0`.
  - `var q:cstr const := name` is kelvinc's `const uint8_t *const q`;
    kc reads the const and writes none, so that `q := other` is C's to
    kelvinc and built by kc.
  - `volatile` of a struct, and `const volatile` of what is no pointer,
    are read by kc as kelvinc reads them, and tried by no test.
- Found while #727 was made, not changed:
  - A struct written before an `#inline C` that holds one of its types
    is C's error in both; a function written before it that takes a
    struct written after it, which holds its type, is kelvinc's C's
    error, and kc's build.
  - `while (i == 0) (i) += 1` is kelvinc's `assignment is a statement
    in Kelvin, not a value`, and kc's `expected '{': the body of
    'while' is a block`.
- The user's order after #723, go on with them all, each pushed when
  its battery is clean:
  - the two differences found while #717 was made (#724);
  - `(T?){}` and `x:T? = {}`, none in both compilers, as an Optional
    declared with no value, the user's answer (#725);
  - `q[i]` of a `q:[T](N)^`, read by kc as kelvinc reads it, the user's
    answer, where kc said its own error of #362 (#726);
  - the 30 programs kc does not build, in batches, `#inline C` passed
    through to C among them:
    - `#inline C` (#727): inline_c, inline_c_fn, inline_c_hash,
      no_trigraphs, stmt_macros;
    - lines that go on and five forms beside them (#728):
      semicolons_edge, semicolons_more, pointer_step, methods_edge,
      order_free, tag_names_edge;
    - C's types and values (#729): casts_edge, casts_edge2,
      casts_edge3, cstr, text_numbers, text_numbers_more,
      function_types, nowhere, is_null, addr, properties_c;
    - the last eight (#730): io_process, io_kill, io_signal,
      coalesce_text, anonymous_edge, array_types, anonymous_values,
      local_storage; with them all 30 are built, the order done.
- Self-hosting's mid goal, no C emission, has no number yet.

## Provisional rows

- None: the reviews confirmed every row to P740, and a review's own
  detail row is confirmed by that review (#675).

## Open design

- Closures and protocols: neither is in 0.4.0, and protocols come first
  when one is taken up.
- `long double` and `f128` have no Kelvin spelling yet.
- Safe primes of `<Prime>`, a prime p with (p - 1) / 2 prime, as
  OpenSSL's `BN_generate_prime_ex` makes with `safe`: not now, as the
  user answered for #672.
