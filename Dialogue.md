

### 157. Values whole, and `.pretty`

> now give println of a struct its .cstr text and Array's elements in
> `[]` and `Dictionary` key-value pairs in `{}`. And add `print` and
> `println` and option to pretty-print values in `()`, `[]`, and `{}`,
> indented and line-fed.

**Claude** found the struct part done by #122 in another session, and
asked two things: how the pretty option is spelled, and how text shows
inside a value. The user chose a property, `x.pretty`, and quoted text.
#123: kelvinc writes a printer for each type, so `print` shows a
struct, an enum with values, an Optional, a Result, an Array, a
Dictionary and a Set whole, with Strings inside quoted, also in
`.cstr`. #124: `x.pretty`, the same indented, printed where `print`
shows it and a String elsewhere. Details are provisional P135 and P136.

There are 682 tests, and all pass with clang and with gcc 15.
