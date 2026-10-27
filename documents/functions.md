# Functions

A function is declared with `let`, its result after the parameter list,
and is a value of its function type. This document has the declaration,
function types, anonymous functions and overloading. Methods and
operators, which are functions of a struct, are in
[structs.md](structs.md).

**Where it lives:** the core. Functions, methods, operators, function types and anonymous functions are kelvinc's own, written as C's, with nothing linked.

## Declaring

```swift
struct node { next: node^ }
let add(a:int64, b:int64):int64 { a + b }        // one expression is the result
let greet(name:cstr) { println("hi ", name) }   // no result: C's void
let shout(name:cstr):() { println(name, "!") }  // the same, written out (#141)
let move(var p:node^):() { p := p^.next }  // a var parameter may change
extern let puts(s:cstr):int32                  // a prototype, no body: C's
static let helper():int32 { 1 }
let main(argc:int32, argv:[cstr]):int32 { return 0 }
```

- **Functions** are declared with `let` (#45), as a value that never
  changes is; methods and operators too. The return type follows the
  parameter list after a colon: `let add(a:i64, b:i64):i64 { ... }`.
  - A function is declared at the top level, or inside a function
    (#180), where its name is the block's: see below.
    - `var f(...)` is an error, since a variable holding a function is
      `var f:(T):R` (#31).
    - So is `let f(...)` inside a function, where a let holds an
      anonymous function (#32).
  - A prototype ends with `;` or the end of its line instead of a body.
  - **`inline`** (#392) goes before `let`, or before or after `static`:
    `inline let sq(x:i64):i64 { x * x }`, on a function, a method, an
    operator, an attribute and a function of the type, in `extend` too.
    - It is C's `static inline`: a program is one C file, where that
      means exactly "inline this here", and C11's bare `inline` would
      need a definition elsewhere besides.
    - `cc -O2` inlines a small function anyway; in a module, an inline
      function keeps its body in `M.kh`, so that the programs that
      import it inline it too (see [modules.md](modules.md)).
    - On a variable, a type or an `extern` prototype, on `main`, or
      written twice, it is an error.
  - With no `: type`, the function returns nothing (C's `void`)
    *(provisional P5)*.
    - `:()` says so in writing (#141): `let shout(name:cstr):() { ... }`.
      It goes on a prototype, a method, an anonymous function,
      `{ (n:i64):() in ... }`, and in a function type, `(i64):()`.
    - It is optional: `greet` and `shout` above mean the same, and
      either spelling goes anywhere a function is written.
    - `:():R` is a function type as the result, as before.
  - Empty parentheses mean no parameters, i.e. C's `(void)` *(provisional P4)*.
- **Parameters** are lets unless written `var`.
  - In `let f(p:u8^)`, `p` cannot change, while
    `let f(var p:u8^):() { p := p.next }` may move `p`.
  - A method's `self` is a let too (#138): a copy, `var p = self`,
    changes; see [structs.md](structs.md#methods).
  - A parameter written `_` is unnamed (#388), as C's `f(int)`: the
    function takes the argument and never reads it.
    - `let on_signal(_:i32) { ... }` fits a callback's signature;
      `_` may stand for several parameters, `let last(_:i64, _:i64,
      z:i64):i64`.
    - Reading `_` is an error, and so is reading the name kelvinc
      gives it in the C, `_kv_arg0` for the first.
    - An anonymous function's is still `$0`, `$1`, ...:
      `{ (_:i64, _:i64):i64 in $0 + $1 }`, and `{ _, b in b }` names
      only its second.
- **An argument is of its parameter's type** (#257), as a
  declaration's value is (#255), once converted and lent: text becomes
  a String, a `T` or `none` an Optional, an owner an expression gives
  is lent where a borrow is taken.
  - A number takes any number, as C converts it; a pointer any
    pointer.
  - Another type is an error, `'x' of 'half' is an f64, and this is
    text`, a method's named `'pt.moved'`.
  - A value where a borrow of it is taken says to write `&`: `'n' of
    'length' is a node^, and this is node: give a borrow, '&a'`.
  - C's own functions, a C typedef and a function type are left to
    C.
  - A call with no value is no argument (#316), C's function's
    included: `println(greet("x"))` is an error that says to make the
    call alone, as a line of its own.
    - So is a method with none, a Kelvin one or a built-in one, as
      `f.print(...)` or `xs.clear()`.
    - So is `await t` of a Task of a function with no result.
- **`return {...}`** (#77) takes the function's result type, as a
  declaration's `{...}` does.
  - `return {0, 0}` in a function that returns a `point`.
  - `{.y = 7}` with a designator, a union's or a C struct's.
  - An enum with values' `{.n = 0.5}`.
  - The value of a `Result<point, U>` or a `point?`, wrapped.
  - A number's result still takes a value, not a list.
- **A `bool` result is a `bool`** (#240): each value a function of a
  `bool` result returns, a body's one expression too, is a `bool`, by
  its type or by its shape, as a comparison's.
  - `return n % 2` is an error that says to compare, as in `x != 0`,
    and `return 1` one that says `true` or `false`, where C would make
    the number a `bool`.
  - So of a method, an anonymous function and a filter's (#239).
  - A value only C sees, as `isdigit(c)`, is C's to convert.
- **`main`** is C's, with one form, and its end returns 0; see
  [grammar.md](grammar.md) for the one-expression rule.

## A function inside a function

A function may be defined inside another (#180), where it is used:

```swift
let main():int32 {
    let fib(n:int64):int64 { n < 2 ? n : fib(n - 2) + fib(n - 1) }
    println(fib(10))                      // 55
    return 0
}
```

- It is a function of the program as one at the top level is, in C a
  `static` function named `_kv_main_fib`, written before the function
  around it: it calls itself, other functions and the globals.
- Its name is the block's: it hides a function of the name outside,
  and is gone at the block's end, as a variable is.
- It sees its parameters, not the locals of the function around it,
  as an anonymous function does not: C has no closures. Pass them as
  arguments, or make them globals.
- It has a body; a prototype is written at the top level.

## `$(...)`: the function itself

`$(...)` (#181) calls the function it is written in, as JS's
`arguments.callee` does: a function at the top level, one inside a
function, an anonymous one, which has no name to call, or a function
of a type.

```swift
let fib(n:int64):int64 { n < 2 ? n : $(n - 2) + $(n - 1) }
let main():int32 {
    let fact:(int64):int64 := { (n:int64):int64 in n < 2 ? 1 : n * $(n - 1) }
    println(fib(10), " ", fact(5))        // 55 120
    return 0
}
```

- The arguments are the function's own, in number and in type, with
  the owner rules of any call.
- In a method or an attribute, `self.name(...)` says it, and `$(...)`
  is an error that says so.

## Functions of a type: `static let T.name(...)`

A function of a type is declared on a struct, union or enum of the
program, and on `Bytes` or `String` in an `extend` (#168):
`Bytes.unescape(text, &re)` of the RegExp module is one.

In an `extend T { }` block (#130), the same is `static let name(...)`;
see [properties.md](properties.md#attributes-of-your-own-and-extend).

`static let T.name(params):R { ... }` (#111) declares a function of the
type `T`, Swift's `static func`: it has no `self`, and is called by the
type's name, `T.name(args)`. `T` is a struct, a union or an enum with
values of the program, declared before it; a built-in type takes none.

The overloads of one name differ by their parameter types, as any
function's do, and one may call another:

```swift
struct point { x: int64; y: int64 }
static let point.origin():Self { (Self){0, 0} }             // Self is point (#140)
static let point.of(x:int64, y:int64):Self { (Self){x, y} }
static let point.of(s:cstr):Self { Self.of(int64(s), 0) }
let point.dist2():int64 { .x * .x + .y * .y }                 // a method, with self, beside them: .x is self.x

let o = point.origin()
let p = point.of(3, 4)
let q = point.of("5")
println(p.dist2())                        // 25; p.origin() is an error: it is called as point.origin()
```

- `self` in its body is an error that says so, and so is calling it on
  a value, `p.origin()`.
- `Self` is `T` in its body and its types (#140): `static let
  point.origin():Self { return {0, 0} }`; see
  [properties.md](properties.md#attributes-of-your-own-and-extend).
  - A function of a type is not a method, and a method,
    `let T.name()`, is not called by the type's name.
- A `static let T.name()` used to be a method with C's `static`; a
  file-local method had no use, and the plain `let T.name()` serves.
- In C it is `T__name`, with its parameter types appended when it
  overloads or comes from an imported file, as `point__of__i64__i64`.

## Function types: `(T, U):R`

A function type is written as a function's head without names (#31), as
Swift writes `(T, U) -> R`. In C it is a pointer to a function:

<!-- fragment -->
```swift
let fold(xs:int64^, n:size_t, f:(int64, int64):int64):int64 { ... f(acc, xs[i]) ... }
let pick(product:bool):(int64, int64):int64 { ... }   // returns a function

var f:(int64, int64):int64       // C: int64_t (*f)(int64_t, int64_t) = 0;
f := add                   // a reference: assigned with :=
let t:() := tick           // no parameters, no result
let u:():() := tick        // the same, the result written out (#141)
```

- `(T)` has no result, as a function without `:R` has none, and `...`
  ends a variadic one: `(i32, ...):i64`. The parameters are types
  without names.
- A function type is a reference (P32): it is assigned with `:=`, is
  `nullptr` until assigned, and is compared with `nullptr`
  (`if f != nullptr`). A `let` one is a `const` pointer.
- The result takes every suffix after it, so `(i64):i64^` returns a
  pointer.
  - **A pointer to a function type** groups it in parentheses,
    `((i64):i64)^` (#403), C's `int64_t (**)(int64_t)`, as kelvinc
    prints the type of `&f`: `let pf:((i64):i64)^ := &f`, then
    `pf^(3)`, or `out^ := g` to hand a function back.
  - **An array of functions** is any array's spelling, `[(i64):i64](4)`
    (#403); `Array<(i64):i64>`, `Set` and `Dictionary<String, (i64):i64>`
    hold them too, a dispatch table: `table["inc"]!(5)`.
  - `typealias op = (i64):i64` (#403) names a function type, which
    `^` may follow, `op^`, and which reads where any type goes:
    `[op](4)`, `Array<op>`, `let apply(f:op, n:i64)`.
- A Kelvin function's name has its function type.
  - `let g:(i64):i64 := f` works, `if f {` asks for a comparison, and
    `f.size` is a pointer's size.
  - `?:` between functions is a function too.
- Where kelvinc sees a function, its `.cstr`, `.next` and `.prev`, and
  `print` or `println` of it (or of `&f`), are errors. In a struct's
  derived text, a function member is its address.
- A C function with `char` parameters does not match a Kelvin function
  type with `u8^` ones.
  - C's `char` and `unsigned char` make incompatible function types, so
    `let p:(const u8^, ...):i32 := printf` fails.
  - Wrap it instead: `let cmp:(cstr, cstr):i32 := { strcmp($0, $1) }`
    *(provisional P43)*.

## Anonymous functions: `{ ... }`

An anonymous function is `{ ... }` (#32). It encloses nothing, since C has
no closures: kelvinc makes it a `static inline` function of its own
(#33), declared before the declaration around it and defined after it.
`async f(x)` makes a call on a thread of its own (#312,
[tasks.md](tasks.md)), passing the arguments as any call does, since
there is no closure to take them.

With `kelvinc -O`, the C compiler may then inline it where it is called,
as in a Kelvin `sort` that calls its `before`; one passed to a C
function such as `qsort` stays a function, whose address C needs.

<!-- fragment -->
```swift
sort(xs, 8) { $0 < $1 }                 // the last argument, after the call
sort(xs, 8, { $[0] > $[1] })            // or inside the parentheses
each(xs, 3) { total += $0 }             // no result: one assignment is fine
let inc:(int64):int64 := { $0 + 1 }
qsort(names, 4, sizeof(cstr)) { (a:const any^, b:const any^):int32 in
    strcmp((a as const cstr^)^, (b as const cstr^)^)
}
```

- **Its parameters** are `$0`, `$1`, ..., also written `$[0]`, `$[1]`,
  (inside the function; elsewhere `$[a, b]` is an `Array`, #62).
  - kelvinc sees their types from one of these:
    - the parameter of a Kelvin function, method or function value it
      is passed to;
    - a declared variable;
    - a member of a struct in an initializer list (`{ $0 - $1 }` for a
      member `sub:(i64, i64):i64`);
    - an assignment's target;
    - the result of the function it is returned from.
  - For `x.map { ... }` of a Result or an Optional (#80), `$0` is the
    value, and the result is the body's one expression's type where
    kelvinc sees it (a bool, a literal, a call, `i64(...)`); else write
    the parameters and the result.
  - Where kelvinc sees them so, the parameters may be named without
    their types, `{ a, b in a + b }` (#236): as many names as the
    function is called with, of the types those give.
  - Elsewhere, such as for C's `qsort`, whose types kelvinc cannot see,
    it writes them: `{ (a:T, b:U):R in ... }`.
  - Without either, it has none, as for `atexit() { println("bye") }`.
  - A body of one expression that gives an owner,
    `{ (n:i64):String in $`#${n}` }`, returns it (#81).
  - `$[k]` takes a decimal number, and `$` works only in an anonymous
    function.
- **In a declaration without a type**, `{` starts an initializer list, so
  an anonymous function there writes its parameters, even none:
  `let hi := { () in println("hi") }`.
  - One that writes them may stand anywhere a value may, and be called
    there: `c ? { (x:i64):i64 in x + 1 } : dec`,
    `{ (a:i64):i64 in a * 2 }(3)`.
  - In an initializer list, kelvinc follows the members in order and
    designators of one member.
    - A string fills an array member and a value of a struct's type
      fills a struct member.
    - After C's brace elision or `.a.b = ...`, an anonymous function
      writes its parameters.
- **A list is not a value:** where C expects a value, as for
  `memcpy(buf, ['a', 'b'], 2)` or `show([1, 2])`, write a compound
  literal, `([u8])['a', 'b']`.
  - kelvinc says so, rather than taking the list for a function. See
    [arrays.md](arrays.md).
- **A body of one expression** is the result: `{ $0 < $1 }`, wrapped as
  `return` wraps it, a `U` or `none` of a `U?` result, which is written
  `{ (v:i64):i64? in none }` (#114).
  - Without a result, it must do something: a call or an assignment,
    as in `{ total += $0 }`.
  - With one, it may not be an assignment or a call kelvinc sees has no
    value.
  - Any other body is statements, with `return`.
  - The text of `.hex` and friends lives in the function's own buffer,
    so returning it, as in `{ $0.hex }`, `{ $0.hex + 2 }` or
    `{ return $0.hex }`, is an error.
  - A property that makes a new owner is no such text: `s.elements`,
    `d.keys`, `f.string` or `a.pretty` is returned, moved out, also
    through a borrow, `return s^.elements` (#280).
- **It encloses nothing:** using a local, a parameter or `self` of the
  function around it is an error, also in its parameter types.
  - Globals, functions and C's names are fine, as are the global it
    initializes and the ones before it.
  - It may call the function around it.
  - A parameter type that comes from elsewhere keeps its array lengths
    when they are made of numbers and globals.
    - A length that names another function's local or parameter means
      something else here: the outer array becomes a pointer, as C
      makes it.
    - Such a length anywhere else is an error that asks for written
      parameters.
- **Trailing:** after a call's `)`, `{ ... }` is the last argument.
  - At the top level of a statement it starts on the line of the `)`,
    since a `{` on the next line starts a block there.
  - Like any statement, one that ends with it needs no `;` at the end
    of a line (#35); another statement on the same line needs one.
  - In the head of `if`, `while` or `for`, where a body follows, a `{`
    after a call starts the body, so pass the function inside the
    parentheses there: `if some(xs, { $0 > 3 }) {`.
  - Inside any parentheses, an initializer list, or the condition of
    `do ... while`, it stays an argument.
- Written parameters let a declaration infer its type:
  `let mul := { (a:i64, b:i64):i64 in a * b }` *(provisional P44)*.

## Overloading: functions of one name

Functions of one name may take different parameter types, and each call
gets the one its arguments' types fit (#41). C's function of a name is
called only where no Kelvin function has the name (#223); beside one, C's
is declared, and is then an overload too:

```swift
#import <math.h> as C

struct vec { x: float64; y: float64 }

let twice(n:int64):int64 { n * 2 }
let twice(x:float64):float64 { x * 2.0 }
let sqrt(x:float64):float64                                // C's, declared
let sqrt(v:vec):float64 { sqrt(v.x * v.x + v.y * v.y) }   // the inner sqrt is C's

let main():int32 {
    let v:vec = {3.0, 4.0}
    println(twice(4), " ", twice(1.5), " ", sqrt(v), " ", sqrt(2.0))   // 8 3.0 5.0 1.4142135623730951
    return 0
}
```

- **C's function of the name** is called only where no Kelvin function
  of the name is declared before the call (#223).
  - Beside a Kelvin one, declare C's, `let sqrt(x:f64):f64`: a
    function the program declares but never defines is C's, keeps its
    C name, and is an overload like any other.
  - Arguments that fit no overload are an error, never a call of C's.
  - A call before the Kelvin function is declared is C's, as in C.
- **The choice** is the overload that every argument fits exactly, or
  else the one that fits at least as well as every other on each
  argument and better on one.
  - A number converts to any number and a pointer may gain `const`, as
    C converts arguments.
  - An argument's type is its value's.
    - A literal has its own, also negated: `4` and `-4` are `i64`,
      `0.5` an `f64`, `'a'` a `u8`.
    - A comparison is a `bool`, an enumerator its enum, and `n * 2` the
      type C gives it (a literal in arithmetic is C's `int`, so
      `small * 4` is an `i32`).
    - A text literal fits a `String`, which it becomes (#223): with
      `h(v:String)` and `h(v:i64)`, `h("x")` calls the first.
  - A tie is an error, as for an `i32` given to `twice` above: convert
    it, `twice(n as i64)`.
  - **Optionals and Results** (#222):
    - `none` fits an Optional alone, and `ok(v)` and `err(e)` a
      Result whose case takes `v`.
    - A `T` fits a `T?` only where no overload takes the arguments as
      they are: with `g(v:i64)` and `g(v:i64?)`, `g(5)` calls the
      first, `g(none)` the second.
    - A `none` that two Optionals take is a tie: say which, as in
      `f(Optional<i64>())`.
  - Where no overload fits, it is an error (#223).
  - An owner given where an overload takes a borrow of it is an error
    that says to pass `&x`.
- **Where only C sees a type**, as for what a C function returns, C
  chooses.
  - Structs, pointers and C typedefs by their type, numbers by their
    Kelvin type, and enums after the numbers.
    - `twice(atan2(y, x))` calls `twice(x:f64)`, and
      `twice(strtol(s, nullptr, 10))` `twice(n:i64)` wherever `long`
      has 64 bits, as C's `long` and `long long` are both `i64` there.
  - A number of a type no overload takes goes to the one that takes a
    number there, and a pointer to the one that takes a pointer
    (`char *` to a `u8^`).
    - Where none does, or several do, C reports `kv_no_such_overload`.
    - C's own function is among them only where it is declared, as
      `let sqrt(x:f64):f64` makes `sqrt(fabs(x))` C's (#223).
  - gcc gives a bit-field of a C header no type C can choose by, and a
    C macro like `isnan` cannot take such a value beside an overload of
    its name.
- **Overloads differ in their parameter types**, not only in their
  results, nor in a parameter's own `const`.
  - A prototype and its definition are one overload.
  - `main` has one form, and methods are chosen by their receiver
    instead.
- **A function's name as a value** is the overload of the function type
  wanted: `let f:(i64):i64 := twice`, a parameter of that type, or a
  function's result.
  - Where no Kelvin overload has that type, it is an error (#223): C's
    function, declared, is one, as `let g:(f64):f64 := sqrt` beside
    `let sqrt(x:f64):f64`.
  - An anonymous function given to an overloaded function writes its
    parameters' types where the overloads differ in them.
- **In C**, a function with overloads, one from an imported file, and
  one that shares a name with a C function the program calls before it
  is declared are named by their parameter types, as `twice__i64` and
  `sqrt__vec`.
  - The program's other functions keep their names, and so does a
    function it declares but never defines, which is C's.
  - A Kelvin function of a C function's name that the program neither
    calls as C's nor declares keeps its name, which conflicts with the
    C header's, as in C.
  - Two functions that would have one C name are an error.
- **As in C**, a call sees only the overloads declared before it.
- **Methods overload too** (#158): `let box.add(n:int64)` and `let
  box.add(t:cstr)` are two methods, and `b.add(1)` and `b.add("x")`
  each call theirs, chosen as a function's overloads are.
  - An anonymous argument, `b.add() { $0 * 10 }`, takes the type of
    the overload that has a function type where it stands, where one
    does: so `s.replace(&re, "$1")` and `s.replace(&re) { ... }` are two
    methods of `String`, and `s.match(&re)` and `s.match(&re) { ... }`,
    `s.split(&re)` and `s.split(&re) { ... }` four more
    ([regexp.md](regexp.md)).
  - In C the overloads are `box__add__i64` and `box__add__cstr`, by
    their types, where a method with one signature stays `box__add`.
- **An owner given by value moves** into a method, and into a call
  through a function value, `f(b)` with `f:(box):int64`, as into a
  function (O5 in [ownership.md](ownership.md)); the callee, an
  anonymous function too, frees it when it ends.


## Properties and methods

| On | Property | Gives |
|---|---|---|
| a function, a function value | `.isNull` | whether it is null, a `bool` |
| | `.addr`, `.hex` | its address, as a number and as text |
| | `.size`, `.typename` | a pointer's size; `(i64):i64` |
| | `f(...)`, `f { ... }` | a call, with a trailing anonymous function |

A function has no `.cstr` and cannot be printed: print its `.hex`.
