

### 156. A template of a struct's .cstr

> `${p.cstr}` segfaults kelvinc

**Claude** found that a template showed a struct by its `.cstr`, and
took `p.cstr`, which keeps the struct's type to size its text, for the
struct itself, so wrapped it again as `p.cstr.cstr`. The user agreed to
ask the value's type instead, as print does since #122: a `.cstr` is
text, and a property that gives a struct, `f.stat` (#104), is still
one. A bug fix, with no change to the language.

There are 680 tests, and all pass with clang and with gcc 15.
