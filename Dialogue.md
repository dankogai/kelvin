

### 153. An enum with values and no tag, at the top level

> now add an anonymous `enum` with values at the top level

**Claude** found a nameless enum already went where a type goes, so
the one thing left was the top-level declaration itself, and asked
what it should mean. The user chose C's reading: #120, its cases are
words of the program, `red` a value and `rgb({1, 2, 3})` a maker of
the type spelled `enum{red, rgb: ...}`, with the words of Result and
Optional, a function's name and an enumerator's refused as case names.
Details are provisional P132.

There are 675 tests, and all pass with clang and with gcc 15.
