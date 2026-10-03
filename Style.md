# Kelvin style

How Kelvin code is written in this repository: the examples, the tests,
the samples in the docs, and the code that kelvinc's hints suggest.
kelvinc accepts any layout; these are conventions, agreed in
[Dialogue.md](Dialogue.md) entry 43.

## Braces

A block opens on the line that introduces it, a function's or a method's
included, and closes on a line of its own:

```kelvin
sum(var n:node^):i64 {
    var total:i64 = 0;
    while n != nullptr {
        total += n^.value;
        n := n^.next;
    }
    return total;
}
```

`if`, `while`, `for` and `struct` read the same way. As the code already
does, `else` follows the closing brace (`} else {`), and a short body may
stay on one line: `positive(n:i32):bool { return n > 0; }`.

## Indentation

Four spaces.

## Types

No space after a type's colon: `x:i32`, `let s:cstr := "hi";`,
`f(a:i64, b:i64):i64 {`, `struct point { x:i32; y:i32; };`,
`for b:u8 in 250...255 {`. It is the same colon as in an annotation,
`0xdead:u16`. Other colons keep their spaces: `c ? a : b`, labels
(`again: n = 0;`) and `case 1:`. The text that `.cstr` derives for a
struct, `{x: 3, y: 4}`, is output, not code.
