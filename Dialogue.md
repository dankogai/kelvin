

### 150. `"""` on its own lines, and a longer delimiter

> now add a longer delimiter for `"""` inside `"""`. also use `"""` /
> multi-line quotation / `"""` instead of `"""multi-line quotation"""`
> to emphasize it is truly multi-line through entire documents

**Claude** added #118: the delimiter is a run of three or more quotes,
closed by a run as long, so `""""` holds a `"""`; and the form on its
own lines, with Swift's rules: the line breaks beside the delimiters
are not text, and the closing delimiter's indentation comes off each
line. The documents write every `"""` that way now; the inline form
stays. Details are provisional P130.

There are 667 tests, and all pass with clang and with gcc 15.
