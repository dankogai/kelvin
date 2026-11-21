# TODO

What is left, checked against the code after #666; done since #657: the
crash of a struct that holds itself (#659); and the wrong message of a
cstr's byte set, which was none: `let s = "abc"` is the error there, as
text is declared with `:=`, and `s[0] = 65` of `let s := "abc"` says a
cstr is immutable (#660); a constant index past a fixed array's end,
kelvinc's error (#661); an integer divided by a constant 0, kelvinc's
error (#662); a literal that does not fit its type, kelvinc's error
(#663); a constant shift past its type's width, kelvinc's error (#665);
the reviews of P662 to P674 (#664, #666, #670); and a member of arithmetic
whose type is C's, `(n + 1).foo` of a `u8`, which is kelvinc's `i32 has
no member 'foo'`, where it was C's error (#669). Each item becomes a
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
  - The CHANGELOG entry, from #651 on: #651 to #671 so far.
  - The version: kelvinc's KELVIN_VERSION and the VS Code package's.
  - The README's line of the release notes.
  - The tag and the release.

## Faults in kelvinc

- None known: a member of arithmetic, `(n + 1).foo`, is kelvinc's error
  (#669).
- The sweep's three that C only warned of are kelvinc's errors (#661 to
  #663), and so is a constant shift past its width (#665).

## kc

- kc says each of the 1019 programs kelvinc refuses in kelvinc's words:
  the 990 of #652 to #656, and those of #659 to #665 alike.
- 29 places where kc reads not yet what kelvinc reads:
  - a function defined inside a function (#180);
  - an enum with no name whose cases have values (#120), the methods of
    a type with no tag (#121), and a plain enum with no name in a
    block;
  - a parameter's array of arrays whose inner count C computes;
  - a fixed array in another type, `(T){...}` and an array's compound
    literal of other types;
  - printing and showing some types: a fixed array that is a parameter,
    one in a template;
  - a value's text in a global's initializer;
  - `typeof` of an expression, and `x.type` where `x`'s type is
    inferred;
  - overloads of a variadic function, an atomic pointer, a pointer
    walked up to a 0, and the number of a prelude enum's word.
- kc writes `const const` of a top-level `let p := "x"`, which C warns
  of.
- Self-hosting's mid goal, no C emission, has no number yet.

## Provisional rows

- P675 and P676, the details of #670 and #671, until reviewed.

## Open design

- Closures and protocols: neither is in 0.4.0, and protocols come first
  when one is taken up.
- `long double` and `f128` have no Kelvin spelling yet.
