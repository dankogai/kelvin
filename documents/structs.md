# Structs

A struct is declared as in C, with members written `name: type`, and is
a type by its bare name. This document has the declaration, the
initializers, the derived text, methods and operators. Unions follow
the same rules; see [unions.md](unions.md).

**Where it lives:** the core. A struct is C's, with nothing linked; its derived text, `.cstr`, and a struct that owns are written with the prelude's functions, which `libkelvin` holds, linked without an import.

## Declaring

```kelvin
struct point { x: i32; y: i32 }
struct node {
    value: i64
    next:  node^            // the bare name, inside its own struct too
}
var p:point = {3, 4}        // C: struct point p = {3, 4};
let q = (point){.y = 7}     // a compound literal; q is a point
```

- **Struct and union members** are written `name: type`, ended by `;` or
  a new line, with no keyword: `struct p { x: i32; y: i32 }`
  *(provisional P8)*.
- **A struct, union or enum is a type by its bare name** (#29), as if C
  had `typedef struct point point;`.
  - `var p:point`, `next: node^` inside `struct node`, `sizeof(point)`,
    `(point){1, 2}`, `c:color` for `enum color`. `struct point` still
    works too.
  - kelvinc resolves the name itself and writes `struct point` in the
    C, so a variable or function may share the name; in an expression
    the name is that variable, from its own declarator on, as in C.
  - In `sizeof(name)`, a function of the same name does not count
    (`sizeof(node)` inside a constructor `node()` is the struct's
    size).
  - A struct from a C header has a bare name once Kelvin declares it,
    as in `struct timespec`, but in `sizeof` write
    `sizeof(struct timespec)`, since headers give such names to
    functions and variables too (`stat`, `timezone`)
    *(provisional P41)*.

## Without a tag: `{x:f64, y:f64}`

A struct may be written where a type goes, by its members alone (#59):

```kelvin
var v:{x:f64, y:f64} = {3.0, 4.0}
let norm(v:{x:f64, y:f64}):f64 { return v.x * v.x + v.y * v.y }
var a = ({x:f64, y:f64}){1.0, 2.0}      // a compound literal
var n:{p:{x:f64, y:f64}, tag:i32} = {{5.0, 6.0}, 7}
var xs = Array<{x:f64, y:f64}>()
println(v.typename)                     // {x: f64, y: f64}
```

- **The members** are written as a struct's, `name: type`, separated by
  `,`, `;` or a line break, and at least one is needed.
- **One spelling is one type:** every `{x:f64, y:f64}` in a program is
  the same struct, so a value passes between them, while `{x:f32}` and
  `{y:f64}` are other structs.
  - A struct takes a value of its own type, and kelvinc says so by the
    Kelvin spellings when the two differ, tagged or not.
- **Everything a tagged struct has**, it has:
  - members, `{...}` initializers with designators;
  - the derived text (`v.cstr`, `${v}`), `.size` and `.typename` (its
    spelling);
  - use as a parameter, a result, a member, an element of an array or
    an `Array<T>`, behind a pointer;
  - and members that own, freed with it (#54).
- **In C** it is a tagged struct kelvinc names, `struct _kv_anon1`, with
  its spelling in a comment, declared before the top-level declaration
  that first writes it.
  - The names `_kv_...` are kelvinc's, and are not written in Kelvin.
- **A union** with no tag is `union{i:i32, f:f32}` (#60), and an enum
  with values `enum{i:i32, f:f32}` (#61): see [unions.md](unions.md)
  and [enums.md](enums.md).
- **Methods and operators** on one name it by its spelling (#121):
  `let {x: f64, y: f64}.norm2():f64 { ... }`, and
  `let +(a:{x: f64, y: f64}, b:{x: f64, y: f64}):{x: f64, y: f64}`.

## Initializers

A struct is initialized with `{...}`, as in C, with C's designators:
`{3, 4}`, `{.y = 7}`, `(point){1, 2}`.

- An array inside it takes `[...]` (#48): `{1, [7, 8, 9], {5, 6}}` for
  a struct of a number, an array and a struct.
  - Where kelvinc sees the type, `[...]` for a struct is an error with
    a hint; see [arrays.md](arrays.md).
- A string fills a byte array member, and a value of the struct's own
  type fills a struct member.
- `return {3, 4}` in a function that returns the struct takes its type
  too (#77), as does a `return {.y = 7}`.

## Text

`p.cstr` is derived text, `{x: 3, y: 4}`, with nested structs and arrays
(`[a, b]`); a string field shows at most 60 bytes. A template shows a
struct the same way, and so do `print` and `println` (#122):
`println(p)` is `println(p.cstr)`. A struct may define its own text
(#53):

```kelvin
struct vector2d { x: f64; y: f64 }
let vector2d.cstr():cstr { `(${.x}, ${.y})` }            // .x is self.x
```

- The body is one template literal (a plain string literal counts),
  whose text kelvinc writes into the caller's buffer, sized from the
  template as every template is (#44).
- `v.cstr`, `${v}` in a template and the derived text of a struct that
  holds a `vector2d` all use it.
- It takes no parameters, gives a `cstr`, is read as a property,
  `v.cstr`, and a built-in type's text stays fixed *(provisional P65)*.
  See [properties.md](properties.md).

## Methods

Every type can have methods. You define them Swift-style on a struct or
union, or on a built-in type, with an implicit `self` (passed by value);
`.x` is `self.x` in them, and `Self` is the type.
Attributes read without parentheses, type attributes, and an
`extend T { }` block that holds them all are in
[properties.md](properties.md#attributes-of-your-own-and-extend) (#130 to #133):

```kelvin
struct point { x: i32; y: i32 }

let point.dist2():i64 { .x * .x + .y * .y }             // .x is self.x
let point.sum():i64 { self.x + self.y }                 // the same, self written
let point.moved(dx:i32):Self {                          // Self is point
    var p:Self = self                                    // self is a let: a copy changes
    p.x += dx
    return p
}
let f64.half():Self { self / 2 }                        // Self is f64

let main():i32 {
    let p:point = {3, 4}
    println(p.dist2(), " ", p.cstr, " ", 3.0.half())   // 25 {x: 3, y: 4} 1.5
    return 0
}
```

- **`self` is a let** (#138): a method reads it and never changes it.
  - `self.x += 1` or `self = v` in a method is an error.
  - It is `const` in C, as any `let` is, so `&self` is a `const T^`.
  - A copy changes: `var p = self`, then `p.x += dx`.
  - What changes the caller's value is a `var` attribute's setter
    ([properties.md](properties.md#attributes-of-your-own-and-extend)),
    or a function that takes `T^`.
- **`.x` is `self.x`** (#139) in a method, an attribute, a setter and a
  subscript: a member, an attribute or a method, `.w * .h`,
  `.scaled(2.0)`, `.is(just)`.
  - In an initializer, `.x = v` is still a designator, and `.x` with no
    `=` is `self.x`: `return {.w * k, .h * k}`.
  - A function with no `self`, and a function of the type, say so.
  - An anonymous function in a method encloses nothing, so `.x` there
    is an error, as `self.x` is (#32).
  - A line that starts with `.x` is `self.x`, a statement of its own
    (#142), so `.is(just) ? .just : 0` may follow a `let` on the line
    before.
    - A chain over several lines goes inside parentheses there,
      `(.xs\n    .count)`, or on one line.
    - Where there is no `self`, a `.member` on a new line goes on with
      the expression before it, as always (#35).
- **`Self` is the type** (#140), Swift's `Self`, in a method and in
  every member of `T`: `let moved(dx:i32):Self`, `var p:Self = self`,
  `Self.origin()`; the details are in
  [properties.md](properties.md#attributes-of-your-own-and-extend).
- **Literals** take methods and properties too: `2.cstr`, `1.5.hex`,
  `(7:i64).inc()` *(provisional P30)*.
  - Hex floats like `0x1.f4p+9` are still numbers.
  - Annotated values need parentheses: `(0.1:f32).cstr`.
- **`toString()`, `fmt()` and `String` are shelved** until Kelvin has a
  true string type (#22).
  - Calling or defining the methods `x.toString()` and `x.fmt(...)`, or
    naming the type `String`, is an error that points at `.cstr`
    *(provisional P36)*.
  - Plain functions, variables and parameters may still be named
    `toString` or `fmt`, as in `let printf(fmt:const u8^, ...):i32`.
- **Dispatch** is chosen by the C compiler (`_Generic`), which brings these
  rules *(provisional P26)*:
  - As in C, declare a method before calling it. A prototype is
    `let point.area():f64`. A method may call itself.
  - A method call cannot appear in a global initializer.
  - C's enums cannot have methods; an enum with values can (#61). A
    function of the type, `static let T.name()`, with no self, goes on
    any of them (#111, [functions.md](functions.md)).
  - C typedef names cannot be receivers, and neither can `cstr` or `any`.
  - `x.name(...)` is a method call only if some type in the file has a
    method `name`. Otherwise it calls through a field, as in C.

## Operators: `let +(a:T, b:T):T`

A struct, a union or an enum with values (#121) may define
`+ - * / % == != < <= > >=` and unary `-`, as functions named by the
operator, overloaded by their types as other functions are (#42):

```kelvin
struct money { cents: i64 }

extend money {                                            // or alone: let +(a:money, b:money):money
    static let +(a:Self, b:Self):Self { (Self){a.cents + b.cents} }
    static let *(a:Self, k:i64):Self { (Self){a.cents * k} }
    static let -(a:Self):Self { (Self){-a.cents} }
    static let <(a:Self, b:Self):bool { a.cents < b.cents }
}

let main():i32 {
    let a:money = {150}
    var b:money = {275}
    b += a                                                // b = b + a
    println((a + b * 2).cents, " ", (-a).cents, " ", a < b)   // 1000 -150 true
    return 0
}
```

- An operator takes two values, or one for `-`, of which at least one
  is a Kelvin struct or union, and has a result.
  - Other operators (`<<`, `!`, `+=`) cannot be defined.
  - Precedence is C's.
  - A definition is a `let` at the top level, `let +(a:T, b:U):R`, or a
    `static let +(a:T, b:U):R` in `extend T { }` (#135), as Swift's
    `static func +`.
- `a op b` with a struct operand calls the operator its types fit, and
  is an error showing how to define one where none does.
  - Numbers keep C's operators.
  - C warns where a statement drops an operator's value, as in
    `m == a` (gcc not where C chooses the operator).
- `x op= y` is `x = x op y`, so `x` is evaluated twice and may not hold
  a call *(provisional P53)*.
  - The same for an enum with values (#128), and for one that owns,
    `x` is read before what it held is freed, so `x += y` keeps its
    value; so does `x = f(x)`.
- Where only C sees an operand's type, C chooses as for functions, and
  a number of another type converts to the one operator that takes a
  number there (C reports `kv_no_such_operator` otherwise).


## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| any struct kelvinc sees | `.member` | a field, a place |
| | `.cstr` | the derived text, `{x: 3, y: 4}`, or `T.cstr()`'s |
| | `.size`, `.type`, `.typename` | `sizeof`; the type; its name, or the spelling of one with no tag |
| | `.method(...)` | a method declared `let T.method()` |
| | `a + b` and the rest | an operator declared `let +(a:T, b:T):T` |
| a struct that owns | `.copy()` | a new struct, each owner member copied (#61) |
| | passing, `return` | a move; `=` is an error |
| with a `[u8]` member | its `.cstr` | up to 60 bytes of it |

A `.hex`, `.dec`, `.addr` or `.isNull` on a struct is an error. A field
with a property's name wins. The details are in
[properties.md](properties.md).
