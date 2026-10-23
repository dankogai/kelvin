# Grammar: declarations, expressions and statements

Kelvin keeps C's grammar where it can. This document has what changed in
the shape of a program: how things are declared, how a type is inferred,
the operators that moved, and how lines end statements. The types
themselves are in [integers.md](integers.md),
[floatingpoint.md](floatingpoint.md), [bool.md](bool.md), [pointers.md](pointers.md)
and [arrays.md](arrays.md); the statements that control flow are in
[flow-controls.md](flow-controls.md).

**Where it lives:** the core. The grammar is kelvinc's own; nothing here needs the prelude.

## Declarations

A variable is declared with `let` or `var`, and the type follows the name
after a colon (#27):

<!-- fragment -->
```swift
let k = 42                 // a let never changes: C's const
var n:int32 = 0              // a var may change
var buf := malloc(n):uint8^   // := for references (see pointers.md)
let a:int32 = 1, b:uint8^ := p
static var calls:int32
```

- **`let` never changes.** `let i = 42; i += 1` is an error, and in the
  generated C a `let` is `const`.
  - A let pointer is fixed, but what it points to may change:
    `let p:i32^ := &x; p^ = 7` is fine.
  - A let array or struct cannot change its elements or fields.
  - A `let` needs a value, except in an `extern` declaration.
- **`var` may change.** `var p:any^` without a value is `nullptr` (#20).
- **A list** shares the keyword: `let a:i32 = 1, b:u8^ := p` declares
  both, each with its own complete type, so C's `int a, *b` split cannot
  happen *(provisional P7)*.
- **A plain `x = 0` assigns**, and never declares.
  - `x:i32 = 0` without `let` or `var` is an error that suggests them.
  - `again: n = 0` is a label before a statement, as in C.
- **Storage classes** go in front: `static let f():i32`,
  `static var n:i32`, `extern var e:i32` *(provisional P9)*.
  - On a dotted name, `static let T.name()` is a function of the type,
    not C's static (#111).
- There is no C-style declaration. `int x;` is an error, and so is `int`
  itself (see [integers.md](integers.md)).

- **`typealias A = T`** (#149), Swift's, names a type anew at the top
  level: from there on `A` is `T` wherever a name is read, as a type,
  before a dot, `A.of(1, 2)`, as a converter, `(A){...}`, and as an
  `extend`'s; `T` is a struct, union or enum with values declared
  before it, or a built-in type.
  - `complex64` is `typealias complex64 = c64` in modules/math.k
    (#150), and `a.typename` is `T`'s name.
  - C's `typedef` is an error that names `typealias` (#294).
  - The number types have full names built in (#151): `int64` is `i64`,
    `uint8` `u8`, `float32` `f32`.
- **Functions** are declared with `let` (#45), as a value that never
  changes is; methods and operators too. See [functions.md](functions.md).
  - The result follows the parameters, `let f(a:i64):i64`; with none,
    the function gives nothing, which `:()` may say, `let f(a:i64):()`
    (#141). The two spellings mean the same.
- **Struct and union members** are written `name: type`, and a struct,
  union or enum is a type by its bare name (#29). See
  [structs.md](structs.md) and [unions.md](unions.md).

### Qualifiers

`const` and `volatile` apply to whatever is on their left. A leading
qualifier applies to the base type, which is C's own rule
*(provisional P6)*. `u8 const^` and `const u8^` are both `const uint8_t *`,
and `u8^ const` is `uint8_t *const`.

### Type inference

A declaration without a type, `let name = value` or `var name = value`,
infers the type from the value:

- an integer literal is `i64`: `let i = 42`, `var m = -1`
- a floating literal is `f64`: `let d = 1.5`, `let e = 1e9`, and so
  are `nan` and `inf` (#261), `let x = -inf`
- a `bool` is `bool`: `var done = false`, `let ok = a < b`,
  `let both = ok && f(x)` (#24, #25), as is a `bool` variable or the
  `bool` result of a Kelvin function or method
- a value with a written type is that type: `let u = 0xdead:u16`,
  `let u = 0xdead as u16` and `let c = u8(300)` are all `u16`/`u8`
- an anonymous function that writes its parameters is its function type:
  `let mul := { (a:i64, b:i64):i64 in a * b }` (#32)
- an array literal is an array of its items' type (#48), as
  [arrays.md](arrays.md) says, and a string literal is a `cstr` (#52):
  `let s := "hi"`, as is a `"""..."""` or a template (see Quoting text)
- any other value whose type kelvinc sees is that type (#47):
  - a Kelvin function's or method's result
    (`var z = c64(0.0, 1.0)`, `let n = p.norm()`), a variable
    (`var q = p`), a field, `p^`, `a[i]`
  - `&x` (`let r := &q`, which points to `const` when `q` is a let)
  - a compound literal, a text property (`let s := n.cstr` is a `u8^`),
    a template, an enumerator (its enum), a character (`u8`), `sizeof`
    (`size_t`), and a `?:` between two values of one type
  - An array is not copied, so `let ap := arr` is the pointer C makes
    of it.

Anything else needs a written type:

- arithmetic (`let y = x + 1`), whose type is C's promotion of its
  operands (`small + 1` is an `i32`, not an `i8`)
- `.size` and `.addr`
- any value only C sees, such as a C function's result
  (`let n = strlen(s)`), a macro, or a `bool` from a C function
  (`let ok:bool = isdigit(c) != 0` is fine, `let ok = is_even(4)` from
  a header is not)

A written type is always what you get: `let b:u8 = 42` is a `u8`.

A declaration cannot be the body of a `for` or follow a label (as in C),
so `for (;;) var x = 1` is an error. Names from C headers, such as
`optind`, are assigned with a plain `optind = 1`, as in C.

## Quoting text

Text is quoted five ways, and each spelling says what the text is, where
it lives, and whether values go into it:

<!-- fragment -->
```swift
let s := "a line\n"                      // C's string literal: C's escapes, a cstr
let c = 'x'                               // C's character constant: a byte, a u8
let t := `n = ${n}, half = ${n / 2.0}`    // a template: text with values, on the stack of the block
let raw := """
    {"a": "b\n",
      "c": 'd'}
    """                                   // as written, over lines: no escapes, no ${...}; a cstr
var u = $"héllo"                          // a String, on the heap, owned
var v = $`${n} items`                     // a String built from a template
var w = $"""
    also as written
    """                                   // a String of a """ text
var b = Bytes("raw bytes")                // a Bytes; Bytes("""...""") too
```

| Spelling | Gives | Over lines | Escapes | `${...}` |
|---|---|---|---|---|
| `"..."` | a `cstr`, C's literal, for the whole program | no | C's | no |
| `'c'` | a `u8`, one byte | no | C's | no |
| `` `...` `` | a `cstr` on the stack of the block, until it ends | yes | C's, `\``, `\$`, a `\` before a line end joins | yes |
| `"""..."""` | a `cstr`, C's literal, as written | yes | none | no |
| `$"..."`, `` $`...` ``, `$"""..."""` | a `String`, on the heap, owned | as the one inside | as the one inside | as the one inside |
| `Bytes("...")`, `String("...")` | a `Bytes`, a `String` of any of the above | as the one inside | as the one inside | as the one inside |
| `$/pattern/flags` | a `RegExp`, with `#import <RegExp>` (#157): [regexp.md](regexp.md) | no | the pattern's own | no |

- **`"..."`** is C's string literal (#52).
  - The escapes are C's, `\n`, `\t`, `\"`, `\\`, `\x41`, `\u00e9`.
  - **`\u{X}`**, `\uXXXX` and `\UXXXXXXXX` are a codepoint (#292), up to
    `10FFFF`, written to C as its UTF-8 bytes.
    - A control character too, `\u{7f}`, which C's own escape
      refuses: so text that `print` shows, `["a\u007f"]`, pastes back.
    - A surrogate, `\u{D800}`, or one past `10FFFF` is an error, as is a
      malformed one, `\u12`; in a template too.
  - Adjacent literals join, `"a" "b"`.
  - **No trigraphs** (#220): `"what??!"` is the text as written.
    - C11 reads `??` and one of `= ( / ) ' < ! > -` as another
      character before anything else, so `??!` would be `|`, and `??/`
      a `\` that breaks the literal.
    - kelvinc writes a `?` after a `?` as C's escape `\?`, in every
      quoted text, a `.typename` and a `#line`'s file name.
  - The text lives for the whole program and cannot be written through.
  - A `cstr` is a reference, so `let s := "hi"`; see
    [strings.md](strings.md).
- **`'c'`** is C's character constant, a `u8` in Kelvin, with C's
  escapes: `'\n'`, `'\0'`, `'\''`.
  - A codepoint is a `uchr`, made from a number, `0x1F600.uchr`; see
    [strings.md](strings.md).
- **`` `...${x}...` ``** is a template literal (#39): the text with each
  `${expression}` replaced by the expression's text, as `print` shows
  it.
  - It may span lines, and a line break in it is a line break in the
    text; a `\` at the end of a line joins the lines.
  - `` \` `` is a backquote, `\$` a dollar, `\{` and `\}` braces, and
    the other escapes are C's.
  - A template with no `${...}` is a plain literal.
  - Its text is a `cstr` kept in a buffer on the stack of the block,
    with room for each value's longest text, and lives until the block
    ends, so it is not returned or kept in an outer variable: copy it.
  - The limits and the rules of the room are in
    [printing.md](printing.md).
- **`"""`** (#115) is a string literal over any number of lines, with
  the text exactly as written.
  - No escapes, so `\n` stays two characters, no `${...}`, and `"` and
    `` ` `` inside as they are.
  - It is a `cstr` as `"..."` is, and joins with a neighbour.
  - It quotes JSON, C, shell or any text that has its own escapes, as
    it is.
  - It is written on its own lines (#118): the opening `"""` ends its
    line, the closing `"""` starts one, and neither line break is text.
    - The indentation of the closing `"""` is taken off every line, so
      the text sits at the depth of the code and starts at its first
      line.
  - A longer delimiter holds a `"""`: `""""` opens and `""""` closes,
    four or more, as long as it began, and the extra quotes of a longer
    closing run are text.
  - `"""as it is"""` on one line keeps everything between the quotes;
    the opening run is the whole run of quotes, so a text that starts
    with a quote goes on its own line.
- **`$"..."`**, **`` $`...` ``** (#67) and **`$"""..."""`** make a
  `String` of the text, on the heap, owned by its variable and freed
  when the block ends, with no bound on its length.
  - The `$` is `String(...)` of what follows, so the spelling inside
    keeps its own rules.
  - `Bytes("...")` is the same for a `Bytes`, which may hold any bytes;
    see [ownership.md](ownership.md).
- **`$/pattern/flags`** (#157) is a regular expression, JS's, a
  `RegExp` owned by its variable: `RegExp.compile("pattern", "flags")`,
  of `#import <RegExp>`, which a file writes before one.
  - The pattern ends at the first `/` not escaped, `\/`, and not in a
    class, `[/]`, on the same line, and is kept as written, so `\d`
    is `\d`; the flags are the letters after it: see
    [regexp.md](regexp.md).
- **Where each lives:** `"..."`, `'c'` and `"""..."""` are C's, in the
  program; a template's text is on the stack of its block; a `String` or
  a `Bytes` is on the heap, and is an owner.

## Expressions

| C | Kelvin | Note |
|---|--------|------|
| `*p` | `p^` | Postfix, so it chains left to right: `p^[i]` is `(*p)[i]` |
| `p->m` | `p^.m` | `->` is an error with a hint |
| `a ^ b` | `a ~ b` | `~` keeps its C precedence slot for XOR |
| `a ^= b` | `a ~= b` | `p^ = x` is always an assignment through `p` |
| `~a` | `~a` | Unary `~` is still bitwise NOT |
| `(int)x` | `i32(x)` or `x as i32` | See [integers.md](integers.md) |

The full table, with precedence, is in [operators.md](operators.md).
Everything else is C's, including precedence, so `6 & 3 == 3` is still
`6 & (3 == 3)`.

The same goes for integer promotion, implicit conversions, `?:`, `,`,
compound literals and designated initializers, except that:

- conditions are `bool` (see [flow-controls.md](flow-controls.md))
- assignment is a statement and so are `p++` and `p--`, for pointers
  only (below)

### Lines end statements; one expression is the result

As in Swift, a `;` may be left out at the end of a line (#35):

<!-- fragment -->
```swift
let total:int64 = price
    * count               // goes on: price * count
println(total)
(p as int64^)^ = 1          // a new statement
let a = 1; let b = 2      // ; between statements on one line
let square(x:int64):int64 { x * x }
```

- A new line ends a statement, a declaration, a struct member or a
  prototype once what is written is complete.
  - An operator, `.member`, `[`, `?`, `:` or `as` at the start of the
    next line goes on with it, and so does any line after one that
    ends with an operator or a `,`.
  - At the top level of a statement, a `(` or `{` at the start of a
    line starts the next statement; inside brackets, lines do not
    matter.
  - A line that starts with `*p =` (a `*` touching what it assigns) is
    C's dereference, an error; `* x` goes on with a product.
- After the head of a function, a method, `if`, `while`, `for` or a
  struct, a `{` on the next line is still its body.
- A `;` still ends a statement anywhere, and separates statements on one
  line, where it is needed; `for (...; ...; ...)` keeps its own.
- A function or method whose body is one expression returns it, as an
  anonymous function does: `let square(x:i64):i64 { x * x }`.
  - There, an assignment, or a call kelvinc sees has no value such as
    `println`, is an error.
  - `main` is the exception: its end returns 0 as in C, so its one
    expression is a statement, and `let main():i32 { printf("hi\n") }`
    exits 0.
- A body with more than that uses `return`.
  - kelvinc reports one that ends, on any path, in a value it drops:
    one with no effect, as in `if x < 0 { -1 } else { 1 }`, or a call
    it sees has a result (in `main`, only the first kind).
- In a function with a result, `return` at the end of a line takes the
  expression on the next line, as in Swift.
  - In one without a result there is nothing to return, so `return`
    ends at its line, and a statement after it in the same block is an
    error, unless it is a `case`, a `default` or a label, or a block
    holding one, which `goto` may reach.
  - `return;` is C's and is not checked.

## Assignment is a statement

Assignment has no value in Kelvin, as in Swift, and `++` and `--` are
statements too, for pointers only (#26, #51):

| C | Kelvin |
|---|--------|
| `i++;`, `--n;` | `i += 1`, `n -= 1` |
| `p++;`, `p--;` (pointers) | `p++`, `p--`, or `p := p.next` |
| `*p++ = *q++;` | `p^ = q^; p++; q++` |
| `a = b = 0;` | `a = 0; b = 0` or `a = 0, b = 0` |
| `while ((c = getchar()) != EOF) { ... }` | `var c:i32 = getchar(); while c != EOF { ...; c = getchar() }` |
| `a[i++] = x;` | `a[i] = x; i += 1` |

- `=`, `:=`, the compound assignments (`+=`, `~=`, ...) and `p++`
  appear only as a statement of their own, or in a `for` clause.
  - Both take a comma list, run left to right:
    `for (var i = 0, j = 10; i < j; i += 1, j -= 1)`, `x = 1, y = 2`
    *(provisional P38)*.
  - A list either declares, after `let` or `var`, or assigns.
- So nothing can be changed inside `[...]`, a condition or an argument,
  except by a function call.

## C habits kelvinc catches

C-style declarations at the start of a statement get the Kelvin spelling as
a hint:

- `size_t * p = &n;` suggests `var p:size_t^`, and `size_t n = 0;`
  suggests `var n:size_t`.
- `const u8 *s` suggests `var s:const u8^`, and `size_t a[3];` suggests
  `var a:[size_t](3)`.
- `static size_t m;` suggests `static var m:size_t`, and
  `size_t f(void);` points to function syntax.

An expression that only looks similar, such as `n * f(x) == 4 || g()`, is
left alone.

One shape cannot be caught, because Kelvin cannot see typedefs: a
statement `name(x)` or `name(x) = v` is a call or a function-like macro,
but if `name` is a C typedef, C reads it as a declaration of `x`. To
convert to a typedef type, write `x as size_t`, never `size_t(x)`.

A converter takes one value, and for text, a base after it
(`i32("755", 8)`); a base after a number is an error. A statement may
start with a converter.

A converter groups its whole argument, so `i32(TOTAL)` is right even if a
header defines `TOTAL` as `1.5 + 2.5` without parentheses. `TOTAL as i32`,
like C's `(int)TOTAL`, converts only the `1.5`.
