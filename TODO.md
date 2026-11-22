# TODO

What is left, checked against the code after #675; done since #657: the
crash of a struct that holds itself (#659); and the wrong message of a
cstr's byte set, which was none: `let s = "abc"` is the error there, as
text is declared with `:=`, and `s[0] = 65` of `let s := "abc"` says a
cstr is immutable (#660); a constant index past a fixed array's end,
kelvinc's error (#661); an integer divided by a constant 0, kelvinc's
error (#662); a literal that does not fit its type, kelvinc's error
(#663); a constant shift past its type's width, kelvinc's error (#665);
the reviews of P662 to P696 (#664, #666, #670, #673 to #675, #679, #691); and a member of arithmetic
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
  - The CHANGELOG entry, from #651 on: #651 to #697 so far.
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

- kc says each of the 1034 programs kelvinc refuses in kelvinc's words:
  the 990 of #652 to #656, and those of #659 to #678 alike.
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
- Places where kc reads not yet what kelvinc reads, 29 as counted after
  #675, ordered taught in batches after #691:
  - a plain enum with no name in a block, and one with values inside a
    type;
  - a parameter's array of arrays whose inner count C computes;
  - a fixed array in another type, and `(T){...}` and an array's
    compound literal of the types left, an Optional's and the like;
  - a value's text in a global's initializer;
  - an atomic pointer, a pointer walked up to a 0, and the number of a
    prelude enum's word.
- kc's output that differs from kelvinc's, found while #692 to #696
  were made, of programs it builds:
  - `a < b ? a > 0 : b > 9` printed, a bool, is `1` (tests/run's
    conditions.k), where kelvinc's is `true`;
  - `.cstr` of a struct with an Array member shows its elements
    (print_values.k), where kelvinc's shows `[...]`;
  - a struct in a template, `${w}`, is its printer's text cut at
    KV_TEMPLATE_STR, 256 bytes, where kelvinc's is its `.cstr`, to the
    struct's own longest text (template_bounds.k, 315 bytes), the same
    root as the one before;
  - `typeof(k)` of a let is `const i64` by `.typename` (typeof.k),
    where kc's is `i64`, as kc's types have no const of a number.
- Self-hosting's mid goal, no C emission, has no number yet.

## Provisional rows

- P697 to P702, the details of #692 to #697, until reviewed; the reviews confirmed
  every row to P696, and a review's own detail row is confirmed by that
  review (#675).

## Open design

- Closures and protocols: neither is in 0.4.0, and protocols come first
  when one is taken up.
- `long double` and `f128` have no Kelvin spelling yet.
- Safe primes of `<Prime>`, a prime p with (p - 1) / 2 prime, as
  OpenSSL's `BN_generate_prime_ex` makes with `safe`: not now, as the
  user answered for #672.
