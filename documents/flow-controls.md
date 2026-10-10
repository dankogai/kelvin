# Flow control

`if`, `while` and `do` take a `bool` without parentheses and a block
body; `for` counts over a range or walks a sequence; and a condition is
always a `bool`. This document has the statements; the rules for lines
and `;` are in [grammar.md](grammar.md).

## Statements

Declarations start with `let` or `var` (see [grammar.md](grammar.md)),
also in `for (var i = 0; ...)`, and references take `:=` (see
[pointers.md](pointers.md)).

`if`, `while` and `do` take their condition without parentheses, and
their bodies are blocks (#23):

```kelvin
if n > 0 {
    println("positive")
} else if n == 0 {
    println("zero")
} else {
    println("negative")
}
while fgets(line, line.size, stdin) != nullptr {
    print(line)
}
do {
    n -= 1
} while n > 0
```

- **`if let x = e { ... } else { ... }`** (#74) binds the value of an
  Optional or a Result when it is present; see
  [optionals.md](optionals.md).
- Parentheses around a condition are only grouping now: `if (n > 0) { ... }`
  still works, while C's `if (n > 0) n = 0;` is an error, since the body
  must be a block. `else` is followed by a block or by `if`.
- C's `for` keeps its parentheses, and its body may still be a single
  statement *(provisional P37)*. To count, prefer a range (below).
- `goto` and labels are C's.

## Switch: a case ends at the next

`switch` is Swift's, not C's (#63): no parentheses are needed, a case
ends where the next begins, with no `break` and no fallthrough, and
every value is handled.

```kelvin
switch n {
case 0:
    println("zero")
case 1, 2:                      // one body for both
    println("small")
    if n == 2 { break }         // break leaves the switch
    println("one")
default:
    println("big")
}
switch s {                      // an enum with values (#61), by its cases
case none: return 0.0
case circle: return 3.0 * s.circle * s.circle
case rect: return s.rect.w * s.rect.h
}                               // exhaustive: no default needed
```

- **The cases** are written at the top of the switch's block, each with
  at least one statement before the next, since a case ends there; a
  case before another with nothing between them is an error, as a C
  programmer would mean a fallthrough: write `case a, b:` for one body,
  or `break` to do nothing. A case inside a statement of the block
  (Duff's device) is an error too. `case` and `default:` are only in a
  switch.
- **Every value is handled:** a switch on an enum with values lists
  every case, a switch on an enum declared in Kelvin every enumerator,
  and any other switch has `default:`; otherwise kelvinc names what is
  missing.
- **`break`** leaves the switch, as in C, and `continue` goes on with
  the loop around it; `return` returns. `goto` is C's.
- **In C**, each case is a block of its own, so a variable declared in
  one is its own, ending with a `break` unless it ends with a jump; a
  switch exhaustive by its cases gets `default: __builtin_unreachable();`,
  so that C sees no path past it. `switch (n) {` still works: the
  parentheses group.

## Ranges: `for i in a..<b`

`for k, v in d { ... }` walks a Dictionary's entries, and `for k in d`
its keys (#65, [ownership.md](ownership.md)).

`for i in a..<b { ... }` counts from `a` up to `b`, without `b`, and
`for i in a...b { ... }` up to and with `b` (#28):

```kelvin
for i in 0..<count {          // C: for (int i = 0; i < count; i++)
    println(i)
}
for i in 1...n { ... }     // C: for (int i = 1; i <= n; i++)
for _ in 0..<3 { ... }     // a loop that needs no counter
for b:u8 in 250...255 { }  // ends, where C's b <= 255 never would
```

- `i` is a `let` in the body, and `a` and `b` are evaluated once.
- `i`'s type is written, as in `for i:u8 in`, or comes from the bounds:
  the upper bound's type if kelvinc sees it (`0..<n` with `n:i32` gives
  `i32`), else the lower one's, else `i64` for literals. A range is of
  integers *(provisional P40)*.
- A bound is an expression down to the shifts, so `0..<n - 1` stops before
  `n - 1`. `continue` and `break` work as in any loop.
- Ranges exist only in `for` for now: there are no range values, and no
  reversed or stepped ranges yet.

## Sequences: `for x in s`

`for x in s { ... }` walks a sequence that ends at a terminator, as C's
strings and lists do (#30). What `x` is depends on `s`'s type:

```kelvin
for c in s { ... }          // s:cstr: each byte, up to the NUL
for arg in argv { ... }     // argv:u8^^: each string, up to nullptr
for n in list.head { ... }  // n:node^: each node along next, up to nullptr
for x in xs { ... }         // xs:[i32](8): up to 8 elements, or the first 0
```

- **A pointer to numbers or pointers** gives `s^`, `s.next^`, ... up to
  the first 0 or `nullptr`. A `nullptr` `s` is empty.
- **A pointer to a struct with a `next` field** is a list: `x` is each
  node's pointer, so `x^.value` reads it and may change it. The next
  pointer is read before the body runs, so the body may `free(x)`.
- **An array of known length** gives its elements, stopping early at a 0
  or `nullptr`; an array of structs gives all of them.
- **An array parameter** is a pointer in C. A let one, `xs:[i32](4)`, is
  walked up to its declared length; a `var` one may have moved, so it is
  walked like a pointer.
- **A pointer kelvinc cannot see**, such as `getenv("PATH")`'s, is walked
  like a pointer.
- `x` is a `let`, `s` is evaluated once and does not move, and
  `for _ in s` names no variable. `for b:u8 in xs` converts each element
  for `b`. A number, `any^`, an array of arrays, a C struct whose fields
  kelvinc cannot see, or an array in a value that a call returns
  (`make().xs`, which C discards before the loop runs) is an error
  *(provisional P42)*.

## Conditions are `bool`

Every condition is a `bool`: those of `if`, `while`, `do` and `for`, the
condition of `?:`, and the operands of `&&`, `||` and `!` (#23). There is
no truthiness, so compare instead:

| C | Kelvin |
|---|--------|
| `if (n)` | `if n != 0` |
| `while (p)` | `while p != nullptr` |
| `if (!p)` | `if p == nullptr` |
| `while (fgets(buf, n, f))` | `while fgets(buf, n, f) != nullptr` |
| `while (1)` | `while true` |

- Comparisons, `&&`, `||` and `!` give a `bool`, not C's `int`, so
  `println(a == b)` prints `true` and `sizeof(a < b)` is 1.
- A `bool` variable, field or function result is a condition as it is, as
  is `bool(x)` or `x as bool`.
- kelvinc reports a non-`bool` condition it can see, with a hint
  (`'x != 0'`, `'p != nullptr'`). Where it cannot see the type, as for C
  functions and macros, the C compiler reports it, naming
  `kv_condition_is_not_bool`: `while fgets(...)` fails that way, and so
  does `if isdigit(c)` (an `int`), which needs `!= 0`.

