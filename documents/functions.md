# Functions

A function is declared with `let`, its result after the parameter list,
and is a value of its function type. This document has the declaration,
function types, anonymous functions and overloading. Methods and
operators, which are functions of a struct, are in
[structs.md](structs.md).

## Declaring

```kelvin
let add(a:i64, b:i64):i64 { a + b }        // one expression is the result
let greet(name:cstr) { println("hi ", name) }   // no result: C's void
let move(var p:node^) { p := p^.next }     // a var parameter may change
extern let labs(n:i64):i64                 // a prototype, no body
static let helper():i32 { 1 }
let main(argc:i32, argv:[cstr]):i32 { return 0 }
```

- **Functions** are declared with `let` (#45), as a value that never
  changes is; methods and operators too. The return type follows the
  parameter list after a colon: `let add(a:i64, b:i64):i64 { ... }`.
  - A function is declared at the top level. `var f(...)` is an error,
    since a variable holding a function is `var f:(T):R` (#31), and so
    is `let f(...)` inside a function, where a let holds an anonymous
    function (#32).
  - A prototype ends with `;` or the end of its line instead of a body.
  - With no `: type`, the function returns nothing (C's `void`)
    *(provisional P5)*.
  - Empty parentheses mean no parameters, i.e. C's `(void)` *(provisional P4)*.
- **Parameters** are lets unless written `var`: in `let f(p:u8^)`, `p`
  cannot change, while `let f(var p:u8^) { p := p.next }` may move `p`. A method's
  `self` is a mutable copy. Parameters must be named: C's unnamed
  `f(int)` is not available yet.
- **`main`** is C's, with one form, and its end returns 0; see
  [grammar.md](grammar.md) for the one-expression rule.

## Function types: `(T, U):R`

A function type is written as a function's head without names (#31), as
Swift writes `(T, U) -> R`. In C it is a pointer to a function:

```kelvin
let fold(xs:i64^, n:size_t, f:(i64, i64):i64):i64 { ... f(acc, xs[i]) ... }
let pick(product:bool):(i64, i64):i64 { ... }   // returns a function

var f:(i64, i64):i64       // C: int64_t (*f)(int64_t, int64_t) = 0;
f := add                   // a reference: assigned with :=
let t:() := tick           // no parameters, no result
```

- `(T)` has no result, as a function without `:R` has none, and `...`
  ends a variadic one: `(i32, ...):i64`. The parameters are types
  without names.
- A function type is a reference (P32): it is assigned with `:=`, is
  `nullptr` until assigned, and is compared with `nullptr`
  (`if f != nullptr`). A `let` one is a `const` pointer.
- The result takes every suffix after it, so `(i64):i64^` returns a
  pointer; an array of functions, or a pointer to a function type, has no
  spelling yet, and kelvinc says so.
- A Kelvin function's name has its function type, so `let g:(i64):i64 := f`
  works, `if f {` asks for a comparison, and `f.size` is a pointer's size.
  `?:` between functions is a function too.
- Where kelvinc sees a function, its `.cstr`, `.next` and `.prev`, and
  `print` or `println` of it (or of `&f`), are errors. In a struct's
  derived text, a function member is its address.
- A C function with `char` parameters does not match a Kelvin function
  type with `u8^` ones: C's `char` and `unsigned char` make incompatible
  function types, so `let p:(const u8^, ...):i32 := printf` fails. Wrap
  it instead: `let cmp:(cstr, cstr):i32 := { strcmp($0, $1) }`
  *(provisional P43)*.

## Anonymous functions: `{ ... }`

An anonymous function is `{ ... }` (#32). It encloses nothing, since C has
no closures: kelvinc makes it a `static inline` function of its own
(#33), declared before the declaration around it and defined after it.
With `kelvinc -O`, the C compiler may then inline it where it is called,
as in a Kelvin `sort` that calls its `before`; one passed to a C
function such as `qsort` stays a function, whose address C needs.

```kelvin
sort(xs, 8) { $0 < $1 }                 // the last argument, after the call
sort(xs, 8, { $[0] > $[1] })            // or inside the parentheses
each(xs, 3) { total += $0 }             // no result: one assignment is fine
let inc:(i64):i64 := { $0 + 1 }
qsort(names, 4, sizeof(cstr)) { (a:const any^, b:const any^):i32 in
    strcmp((a as const cstr^)^, (b as const cstr^)^)
}
```

- **Its parameters** are `$0`, `$1`, ..., also written `$[0]`, `$[1]`,
  (inside the function; elsewhere `$[a, b]` is an `Array`, #62),
  where kelvinc sees their types: from the parameter of a Kelvin function,
  method or function value it is passed to, a declared variable, a
  member of a struct in an initializer list (`{ $0 - $1 }` for a member
  `sub:(i64, i64):i64`), an assignment's target, or the result of the
  function it is returned from. Elsewhere, such as for C's `qsort`,
  whose types kelvinc cannot see, it writes them:
  `{ (a:T, b:U):R in ... }`. Without either, it has none, as for
  `atexit() { println("bye") }`. `$[k]` takes a decimal number, and `$`
  works only in an anonymous function.
- **In a declaration without a type**, `{` starts an initializer list, so
  an anonymous function there writes its parameters, even none:
  `let hi := { () in println("hi") }`. One that writes them may stand
  anywhere a value may, and be called there:
  `c ? { (x:i64):i64 in x + 1 } : dec`, `{ (a:i64):i64 in a * 2 }(3)`.
  In an initializer list, kelvinc follows the members in order and
  designators of one member. A string fills an array member and a value
  of a struct's type fills a struct member; after C's brace elision or
  `.a.b = ...`, an anonymous function writes its parameters.
- **A list is not a value:** where C expects a value, as for
  `memcpy(buf, ['a', 'b'], 2)` or `show([1, 2])`, write a compound
  literal, `([u8])['a', 'b']`. kelvinc says so, rather than taking the
  list for a function. See [arrays.md](arrays.md).
- **A body of one expression** is the result: `{ $0 < $1 }`. Without a
  result, it must do something: a call or an assignment, as in
  `{ total += $0 }`; with one, it may not be an assignment or a call
  kelvinc sees has no value. Any other body is statements, with
  `return`. The
  text of `.hex` and friends lives in the function's own buffer, so
  returning it, as in `{ $0.hex }`, `{ $0.hex + 2 }` or
  `{ return $0.hex }`, is an error.
- **It encloses nothing:** using a local, a parameter or `self` of the
  function around it is an error, also in its parameter types; globals,
  functions and C's names are fine, as are the global it initializes and
  the ones before it. It may call the function around it. A parameter
  type that comes from elsewhere keeps its array lengths when they are
  made of numbers and globals. A length that names another function's
  local or parameter means something else here: the outer array becomes
  a pointer, as C makes it, and such a length anywhere else is an error
  that asks for written parameters.
- **Trailing:** after a call's `)`, `{ ... }` is the last argument. At
  the top level of a statement it starts on the line of the `)`, since a
  `{` on the next line starts a block there. Like any
  statement, one that ends with it needs no `;` at the end of a line
  (#35); another statement on the same line needs one. In the
  head of `if`, `while` or `for`, where a body follows, a `{` after a call
  starts the body, so pass the function inside the parentheses there:
  `if some(xs, { $0 > 3 }) {`. Inside any parentheses, an initializer
  list, or the condition of `do ... while`, it stays an argument.
- Written parameters let a declaration infer its type:
  `let mul := { (a:i64, b:i64):i64 in a * b }` *(provisional P44)*.

## Overloading: functions of one name

Functions of one name may take different parameter types, and each call
gets the one its arguments' types fit (#41). A Kelvin function of a C
function's name overloads C's, which still takes the numbers:

```kelvin
#import <math.h> as C

struct vec { x: f64; y: f64 }

let twice(n:i64):i64 { n * 2 }
let twice(x:f64):f64 { x * 2.0 }
let sqrt(v:vec):f64 { sqrt(v.x * v.x + v.y * v.y) }   // the inner sqrt is C's

let main():i32 {
    let v:vec = {3.0, 4.0}
    println(twice(4), " ", twice(1.5), " ", sqrt(v), " ", sqrt(2.0))   // 8 3.0 5.0 1.4142135623730951
    return 0
}
```

- **The choice** is the overload that every argument fits exactly, or
  else the one that fits at least as well as every other on each
  argument and better on one, where a number converts to any number and
  a pointer may gain `const`, as C converts arguments. An argument's
  type is its value's: a literal has its own, also negated (`4` and
  `-4` are `i64`, `0.5` an `f64`, `'a'` a `u8`), a comparison is a
  `bool`, an enumerator its enum, and `n * 2` the type C gives it (a
  literal in arithmetic is C's `int`, so `small * 4` is an `i32`). A tie is an
  error, as for an `i32` given to `twice` above: convert it,
  `twice(n as i64)`. Where no overload fits, C's own function of the
  name is called *(provisional P52)*.
- **Where only C sees a type**, as for what a C function returns, C
  chooses: structs, pointers and C typedefs by their type, numbers by
  their Kelvin type, and enums after the numbers, so
  `twice(atan2(y, x))` calls `twice(x:f64)`, and
  `twice(strtol(s, nullptr, 10))` `twice(n:i64)` wherever `long` has 64
  bits, as C's `long` and `long long` are both `i64` there. A number of
  a type no overload takes goes to the one that takes a number there,
  and a pointer to the one that takes a pointer (`char *` to a `u8^`);
  where none does, to C's own function of the name where the program
  calls it, as in `sqrt(fabs(x))`; where several do, C reports
  `kv_no_such_overload` *(provisional P52)*. A library that overloads a
  C function declares it, `let tanh(x:f64):f64`, so that it takes such
  numbers whether or not the program calls it. gcc gives a bit-field of
  a C header no type C can choose by, and a C macro like `isnan` cannot
  take such a value beside an overload of its name.
- **Overloads differ in their parameter types**, not only in their
  results, nor in a parameter's own `const`. A prototype and its
  definition are one overload. `main` has one form, and methods are
  chosen by their receiver instead.
- **A function's name as a value** is the overload of the function type
  wanted: `let f:(i64):i64 := twice`, a parameter of that type, or a
  function's result. Where no Kelvin overload has that type, it is C's
  own function: `let g:(f64):f64 := sqrt`. An anonymous function given
  to an overloaded function writes its parameters' types where the
  overloads differ in them.
- **In C**, a function with overloads, one from an imported file, and
  one that shares a name with a C function the program calls are named
  by their parameter types, as `twice__i64` and `sqrt__vec`; the
  program's other functions keep their names, and so does a function
  it declares but never defines, which is C's. A Kelvin function of a C
  function's name that the program neither calls as C's nor declares
  keeps its name, which conflicts with the C header's, as in C. Two
  functions that would have one C name are an error.
- **As in C**, a call sees only the overloads declared before it.

