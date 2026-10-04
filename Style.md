# Kelvin style

How Kelvin code is written in this repository: the examples, the tests,
the samples in the docs, and the code that kelvinc's hints suggest.
kelvinc accepts any layout that keeps each statement's lines together,
as the line rules of #35 ask (see "Semicolons and `return`" below);
the rest are conventions, agreed in [Dialogue.md](Dialogue.md) entry 43.

## Braces

A block opens on the line that introduces it, a function's or a method's
included, and closes on a line of its own:

```kelvin
sum(var n:node^):i64 {
    var total:i64 = 0
    while n != nullptr {
        total += n^.value
        n := n^.next
    }
    return total
}
```

`if`, `while`, `for` and `struct` read the same way. As the code already
does, `else` follows the closing brace (`} else {`), and a short body may
stay on one line: `positive(n:i32):bool { n > 0 }`.

## Semicolons and `return` *(Dialogue.md entry 53)*

A statement ends at the end of its line, with no `;` (#35). A `;` is
written only between statements on one line, as in `a += 1; b += 1`, and
inside `for (...; ...; ...)`. A function whose body is one expression
leaves out `return`: `square(x:i64):i64 { x * x }`. A body of more
statements keeps it, and so does `main`, whose end returns 0 as in C
(Dialogue.md entry 54). The tests keep both forms, to check that `;`
stays valid. A long expression breaks before an operator, written with
a space after it as everywhere, so the next line goes on with it:

```kelvin
let total:i64 = price
    * count
```

## Anonymous functions *(provisional, Dialogue.md entry 47)*

A short one stays on one line, with a space inside each brace:
`sort(xs, n) { $0 < $1 }`. A longer one opens on the call's line, with
its written parameters, if any, before `in`:

```kelvin
qsort(names, n, sizeof(cstr)) { (a:const any^, b:const any^):i32 in
    strcmp((a as const cstr^)^, (b as const cstr^)^)
}
```

A trailing function starts on the line of its call's `)`; on the next
line, `{` starts a block.

## Indentation

Four spaces.

## Types

No space after a type's colon: `x:i32`, `let s:cstr := "hi"`,
`f(a:i64, b:i64):i64 {`, `struct point { x:i32; y:i32 }`,
`for b:u8 in 250...255 {`. It is the same colon as in an annotation,
`0xdead:u16`. Other colons keep their spaces: `c ? a : b`, labels
(`again: n = 0`) and `case 1:`. The text that `.cstr` derives for a
struct, `{x: 3, y: 4}`, is output, not code.
