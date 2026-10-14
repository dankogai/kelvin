

### 151. Documents easier on the eyes

> When you document things, you are squeezing too many sentences in a
> paragraph. look at `io.md`'s `making one`: AIs may have no problem but
> it makes the eyes of NIs sore. Don't be afraid to multi-indent like
> source codes. Make all documents eyeball-easier

**Claude** restructured every document and the README: a dense bullet
is now a lead line of one or two sentences with nested sub-bullets,
one idea each, indented like code. Nothing was added, dropped or
reworded beyond the splitting; every code block, table, heading,
reference and link is as it was, which a checker compared against the
committed files. No code changed.

There are 667 tests, and all pass with clang and with gcc 15.
