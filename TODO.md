# TODO

What is left, checked against the code after #657; done since: the
crash of a struct that holds itself (#659); and the wrong message of a
cstr's byte set, which was none: `let s = "abc"` is the error there, as
text is declared with `:=`, and `s[0] = 65` of `let s := "abc"` says a
cstr is immutable (#660); a constant index past a fixed array's end,
kelvinc's error (#661); an integer divided by a constant 0, kelvinc's
error (#662). Each item becomes a
numbered change of Design.md when it is ordered; this list says what is
known, not what is planned.

## Versions

- So long as the grammar and the semantics stay the same, the version
  stays 0.4.x.
  - A fix, an error in Kelvin's words where C's came, a document, and
    kc reading more of what kelvinc reads are 0.4.x.
  - A change of what a program means, or of what is written, is 0.5.0.
- Release chores are done only when ordered.
  - The CHANGELOG entry, from #651 on.
  - The version: kelvinc's KELVIN_VERSION and the VS Code package's.
  - The README's line of the release notes.
  - The tag and the release.

## Faults in kelvinc

- **C warns, and the program runs**, each to be kelvinc's error (the
  user's order, 0.4.x, #661 to #663):
  - a literal that does not fit the type written, `let c:u8 = 300`,
    which is 44.

## kc

- kc says each of the 990 programs kelvinc refuses in kelvinc's words
  (#652 to #656).
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

- P662 to P667, the details of #657 to #662, until reviewed.

## Open design

- Closures and protocols: neither is in 0.4.0, and protocols come first
  when one is taken up.
- `long double` and `f128` have no Kelvin spelling yet.
