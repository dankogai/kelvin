# Structs

A struct is declared as in C, with members written `name: type`, and is
a type by its bare name. This document has the declaration, the
initializers, the derived text, methods and operators. Unions follow
the same rules; see [unions.md](unions.md).

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
  had `typedef struct point point;`: `var p:point`, `next: node^` inside
  `struct node`, `sizeof(point)`, `(point){1, 2}`, `c:color` for
  `enum color`. `struct point` still works too. kelvinc resolves the name
  itself and writes `struct point` in the C, so a variable or function
  may share the name; in an expression the name is that variable, from
  its own declarator on, as in C. In `sizeof(name)`, a function of the
  same name does not count (`sizeof(node)` inside a constructor `node()`
  is the struct's size). A struct from a C header has a bare name once
  Kelvin declares it, as in `struct timespec`, but in `sizeof` write
  `sizeof(struct timespec)`, since headers give such names to functions
  and variables too (`stat`, `timezone`) *(provisional P41)*.

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
  `{y:f64}` are other structs. A struct takes a value of its own type,
  and kelvinc says so by the Kelvin spellings when the two differ,
  tagged or not.
- **Everything a tagged struct has**, it has: members, `{...}`
  initializers with designators, the derived text (`v.cstr`, `${v}`),
  `.size` and `.typename` (its spelling), use as a parameter, a result,
  a member, an element of an array or an `Array<T>`, behind a pointer,
  and members that own, freed with it (#54).
- **In C** it is a tagged struct kelvinc names, `struct _kv_anon1`, with
  its spelling in a comment, declared before the top-level declaration
  that first writes it; the names `_kv_...` are kelvinc's, and are not
  written in Kelvin.
- **Not yet:** methods and operators on one (they name a tag), and a
  union with no tag.

## Initializers

A struct is initialized with `{...}`, as in C, with C's designators:
`{3, 4}`, `{.y = 7}`, `(point){1, 2}`. An array inside it takes
`[...]` (#48): `{1, [7, 8, 9], {5, 6}}` for a struct of a number, an
array and a struct. Where kelvinc sees the type, `[...]` for a struct is
an error with a hint; see [arrays.md](arrays.md). A string fills a byte
array member, and a value of the struct's own type fills a struct
member.

## Text

`p.cstr` is derived text, `{x: 3, y: 4}`, with nested structs and arrays
(`[a, b]`); a string field shows at most 60 bytes. A template shows a
struct the same way, while `print` takes no struct: write `print(p.cstr)`
or `` print(`${p}`) ``. A struct may define its own text (#53):

```kelvin
struct vector2d { x: f64; y: f64 }
let vector2d.cstr():cstr { `(${self.x}, ${self.y})` }
```

The body is one template literal (a plain string literal counts),
whose text kelvinc writes into the caller's buffer, sized from the
template as every template is (#44); `v.cstr`, `${v}` in a template
and the derived text of a struct that holds a `vector2d` all use it.
It takes no parameters, gives a `cstr`, is read as a property, `v.cstr`,
and a built-in type's text stays fixed *(provisional P65)*. See
[properties.md](properties.md).

## Methods

Every type can have methods. You define them Swift-style on a struct or
union, or on a built-in type, with an implicit `self` (passed by value):

```kelvin
struct point { x: i32; y: i32 }

let point.dist2():i64 { self.x * self.x + self.y * self.y }
let f64.half():f64 { self / 2 }

let main():i32 {
    let p:point = {3, 4}
    println(p.dist2(), " ", p.cstr, " ", 3.0.half())   // 25 {x: 3, y: 4} 1.5
    return 0
}
```

- **Literals** take methods and properties too: `2.cstr`, `1.5.hex`,
  `(7:i64).inc()` *(provisional P30)*. Hex floats like `0x1.f4p+9` are
  still numbers. Annotated values need parentheses: `(0.1:f32).cstr`.
- **`toString()`, `fmt()` and `String` are shelved** until Kelvin has a
  true string type (#22). Calling or defining the methods `x.toString()`
  and `x.fmt(...)`, or naming the type `String`, is an error that points
  at `.cstr` *(provisional P36)*. Plain functions, variables and
  parameters may still be named `toString` or `fmt`, as in
  `let printf(fmt:const u8^, ...):i32`.
- **Dispatch** is chosen by the C compiler (`_Generic`), which brings these
  rules *(provisional P26)*:
  - As in C, declare a method before calling it. A prototype is
    `let point.area():f64`. A method may call itself.
  - A method call cannot appear in a global initializer.
  - Enums cannot have methods.
  - C typedef names cannot be receivers, and neither can `cstr` or `any`.
  - `x.name(...)` is a method call only if some type in the file has a
    method `name`. Otherwise it calls through a field, as in C.

## Operators: `let +(a:T, b:T):T`

A struct or union may define `+ - * / % == != < <= > >=` and unary `-`,
as functions named by the operator, overloaded by their types as other
functions are (#42):

```kelvin
struct money { cents: i64 }

let +(a:money, b:money):money { (money){a.cents + b.cents} }
let *(a:money, k:i64):money { (money){a.cents * k} }
let -(a:money):money { (money){-a.cents} }
let <(a:money, b:money):bool { a.cents < b.cents }

let main():i32 {
    let a:money = {150}
    var b:money = {275}
    b += a                                                // b = b + a
    println((a + b * 2).cents, " ", (-a).cents, " ", a < b)   // 1000 -150 true
    return 0
}
```

- An operator takes two values, or one for `-`, of which at least one
  is a Kelvin struct or union, and has a result. Other operators (`<<`,
  `!`, `+=`) cannot be defined. Precedence is C's. A definition is a
  `let` at the top level, `let +(a:T, b:U):R`.
- `a op b` with a struct operand calls the operator its types fit, and
  is an error showing how to define one where none does. Numbers keep
  C's operators. C warns where a statement drops an operator's value,
  as in `m == a` (gcc not where C chooses the operator).
- `x op= y` is `x = x op y`, so `x` is evaluated twice and may not hold
  a call *(provisional P53)*.
- Where only C sees an operand's type, C chooses as for functions, and
  a number of another type converts to the one operator that takes a
  number there (C reports `kv_no_such_operator` otherwise).

