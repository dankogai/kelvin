

### 155. print shows a struct as its text

> `println(p)` of a struct, or of an enum with values, is not caught by
> kelvinc, and fails in C

**Claude** asked whether kelvinc should refuse such an argument with a
hint to write `p.cstr`, or show its `.cstr` text, and the user chose
the text: #122, `print`, `println`, `f.print` and `f.println` show a
struct, a union or an enum with values that kelvinc sees as `${p}`
does, the derived text or the type's own `T.cstr()`. Details are
provisional P134.

There are 679 tests, and all pass with clang and with gcc 15.
