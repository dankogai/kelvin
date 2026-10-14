

### 149. Quoting text, in one place

> `"""` is not limited to JSON so the snippet in `json.md`. rewrite
> `grammar.md` and other document on how to quote strings including the
> explanation on ``.

**Claude** wrote a section "Quoting text" into grammar.md with every
spelling side by side: `"..."`, `'c'`, the template with its own
escapes, `"""..."""` as written, and the `$` forms and `Bytes(...)`
that make a String or a Bytes of any of them, with a table of what
each gives, whether it spans lines, its escapes and whether values go
in. strings.md, printing.md, json.md and the README now point there
instead of explaining a spelling each. No code changed.

There are 666 tests, and all pass with clang and with gcc 15.
