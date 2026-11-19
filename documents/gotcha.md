# Gotchas: what Kelvin is not

Kelvin reads like Swift, and it is C underneath: what Swift, JavaScript
or Python do behind the scenes, Kelvin does not. This is what a newcomer
looks for and does not find, and what to write instead.

## Synopsis

```swift
// no closure keeps the memo: it is passed, a borrow
let fib(n:i64, memo:${i64: i64}^):i64 {
    if n < 2 { return n }
    if let v = memo^[n] { return v }
    let v:i64 = fib(n - 1, memo) + fib(n - 2, memo)   // no type is inferred from arithmetic
    memo^[n] = v
    return v
}

let main():int32 {
    var memo:${i64: i64} = ${:}
    let k = 3
    var xs:$[i64] = $[]
    for x in $[1, 2, 3] { xs += x * k }        // { $0 * k } cannot see k; a loop can
    let s = $"text"                            // "text" is C's cstr; $"text" is a String
    let t = s.copy()                           // = never copies an owner
    println(fib(90, &memo), " ", xs, " ", t)   // 2880067194370816120 [3, 6, 9] text
    return 0
}
```

## Description

Each section below says what Kelvin lacks, how kelvinc tells you, and
what to write instead (#619). For a C programmer the other way round, what
Kelvin adds to C, see [versusC.md](versusC.md).

### At a glance

| You may expect | Kelvin has | Write instead |
|---|---|---|
| closures | functions that see their parameters and the globals, no local around them | the state passed: an argument, a borrow `&memo`, or a struct and its var method |
| generics of your own, `f<T>`, `Box<T>` | the built-in generic types alone | an overload per type, an enum with values |
| protocols, traits, interfaces | none: a built-in method checks what `T` has where it is used | overloads, a struct's own `<` and `==`, a function passed in |
| classes and inheritance | structs, methods and `extend` | an enum with values, a function member |
| exceptions | `Result<T, E>`, `try`, and checks that end the program | `if let`, `??`, `try` |
| a garbage collector | an owner, freed by its block | `.copy()`, or a borrow, `:= &x` |
| `"..."` a string | `"..."` C's `cstr` | `$"..."`, a String |
| `"${x}"` interpolated | `` `${x}` ``, a template | `` $`${x}` ``, a String of one |
| a type inferred from any value | from literals and the values whose type kelvinc sees, not from arithmetic | `let v:i64 = a + b` |
| default and named arguments | neither | an overload with fewer parameters |
| `i++` | `++` of a pointer alone | `i += 1` |
| a checked array | `[T](N)`, C's: not zeroed, its index not checked | `$[T]`, checked; `[T](N)` as a value, zero-filled |
| safe integers | C's arithmetic | `.pow(e, m)`, a `BigInt` |
| `s[i]` in O(1) | a String's graphemes, walked from its start | `s.codepoints`, `s.bytes` |

### No closures

- **A function sees its parameters, the other functions and the
  globals, never a local of the function around it.**
  - An anonymous function, `{ $0 * k }`, and a function written inside
    a function are each a C function of their own: C has no closures.
  - kelvinc says so where one is tried: `an anonymous function cannot
    use 'k' of the function around it: C has no closures, so pass it
    as an argument, or make it a global`.
- **So none of what a closure gives:**
  - No `makeAdder(n)` that returns a function remembering `n`: a
    function value is a function's address, with nothing beside it.
  - No `xs.map { $0 * k }` of a local `k`: a `for` loop does it, as in
    the Synopsis.
  - No memo, counter, generator or callback that keeps its state in a
    closure.
- **Pass the state instead:**
  - As an argument, a borrow, as `fib(n, &memo)` in the Synopsis.
  - Or in a struct, whose var method changes it
    ([structs.md](structs.md)):

```swift
struct Fib {
    memo: ${i64: i64}
}

var Fib.at(n:i64):i64 {                       // a var method: it changes self
    if n < 2 { return n }
    if let v = .memo[n] { return v }
    let v:i64 = self.at(n - 1) + self.at(n - 2)
    .memo[n] = v
    return v
}

let main():int32 {
    var f:Fib = {${:}}
    println(f.at(90), " ", f.memo.count)       // 2880067194370816120 89
    return 0
}
```

- **An iterator keeps its state in a value**, not a closure:
  `var T.next():E?` of a struct, or `Iterator(state) { ... }`
  ([iterators.md](iterators.md)).
- **`async f(x)`** passes its arguments as a call does: there is nothing
  to capture ([tasks.md](tasks.md)).
- **A global works too,** as kelvinc says, but it is one for every
  caller: two memos, or two threads, share it.

### No generics of your own

- **The generic types are built in:** `Array<T>`, `Dictionary<K, V>`,
  `Set<T>`, `T?`, `Result<T, E>`, `Task<T>`, `Iterator<T>` and
  `Range<T>`.
  - kelvinc writes a C type for each `T` a program uses, so any value
    type goes in, a struct of the program's too.
- **A program cannot write one:** `let id<T>(x:T):T` and
  `struct Box<T> { v: T }` are syntax errors.
- **Nor a protocol:** there is no way to say "any `T` that has `<`".
  - A built-in method checks what `T` has where it is used:
    `xs.sort()` takes `<` of the elements, a number's, a String's or a
    struct's own operator; `xs.contains(x)` takes `==`, and where `T`
    has none, kelvinc says so at that call.
  - That works because kelvinc knows each built-in method; a function
    of the program cannot ask the same of its `T`.
  - `protocol`, `trait` and `interface` are no words of Kelvin.
- **Instead:**
  - Overload by type: `let area(c:circle):f64` and `let area(r:rect):f64`
    are two functions, chosen by the argument's type when compiling
    ([functions.md](functions.md)).
  - An enum with values holds a value of one of several kinds, and a
    `switch` takes each ([enums.md](enums.md)).
  - A function passed in says what a generic one would ask of `T`:
    `xs.sorted { $0.name < $1.name }`.
  - `<Combinatorics>` gives indices, and `seed.gather(ix)` turns them
    into a seed's own elements, since no `Permutation<T>` can be
    written ([combinatorics.md](combinatorics.md)).

### No classes

- **A struct is a value,** with methods, attributes, subscripts and
  operators, declared alone or in `extend` ([structs.md](structs.md)).
  - `=` copies it; a pointer, `^`, refers to one.
- **No inheritance, no subclass, no virtual method:** the method called
  is chosen when compiling.
- **A choice at run time** is an enum with values and a `switch`, or a
  member that is a function.

### No exceptions

- **No `throw`, and no `try { } catch { }`.**
- **An error is a value:** a `Result<T, E>` of `ok(v)` or `err(e)`
  ([results.md](results.md)).
  - `try r` is the `ok` value, or returns the `err` from the function:
    a prefix of one expression, `let n = try parse(s)`, not a block.
  - `if let`, `??` and `switch` read one where it is.
- **What cannot go on ends the program,** with a message on stderr and
  exit status 1: an index out of range, `d[k]!` of a missing key, a
  case read that is not current.
  - Nothing catches it; where the environment has `KELVIN_ABORT`, it
    aborts instead, for a debugger.

### No garbage collector

- **An owner is freed by its block:** a `String`, a `Bytes`, an
  `Array`, a `Dictionary`, a `BigInt`, each a type whose name starts
  with a capital ([ownership.md](ownership.md)).
- **`=` never copies an owner, and never shares one:** `let b = a` of a
  String is an error, `an owner is not copied by '='`.
  - `a.copy()` copies it; `let r := &a` borrows it.
  - `return` and passing it to a function move it.
- **One owner each:** no reference count, no shared object that lives
  while anyone holds it.
- **A pointer is C's:** nothing stops one that outlives what it points
  at.

### Text is C's unless it is a String

- **`"abc"` is a `cstr`,** C's pointer to bytes, not a String
  ([cstr.md](cstr.md)).
  - `let s = "abc"` is an error, `'s' is a reference (cstr): assign it
    with ':=', not '='`; `let s := "abc"` is the cstr.
  - `$"abc"` is a String ([strings.md](strings.md)), and so is each
    text inside `$[...]` and `${...}`.
- **`"${x}"` is text as it is written:** a template is backquoted,
  `` `x is ${x}` ``, and `` $`x is ${x}` `` makes a String of it
  ([printing.md](printing.md)).
- **A String's elements are its graphemes,** what a reader sees as one
  character: `s.count` and `s[i]` walk it from its start, O(n).
  - `s.codepoints` and `s.bytes` are its codepoints and its bytes.

### C's semantics underneath

What Kelvin does not change is C's ([versusC.md](versusC.md)):

- **Integers:** `7 / 2` is 3; `i32.max + 1` overflows as C's does, a
  signed one undefined; `300 as u8` wraps to 44
  ([integers.md](integers.md)).
  - A `BigInt` never overflows, and `b.pow(e, m)` multiplies in 128
    bits.
- **Operators moved:** `^` is a pointer's, `p^`, not XOR; XOR is `~`,
  and unary `~` is still NOT ([operators.md](operators.md)).
- **A fixed array is C's** ([arrays.md](arrays.md)):
  - `var a:[i32](4)` is not filled, as C's is not; `[i32](4)` as a
    value is zero-filled.
  - `a[i]` is not checked.
  - A parameter `a:[i64]` is a pointer, with no count: pass the count
    beside it, or take a `$[i64]`.
  - `$[T]` is the Array that is checked and grows.
- **Assignment is a statement,** with no value: no `a = b = 0`, no
  `if (c = getchar())`; and `++` is a pointer's alone, `i += 1` an
  integer's ([grammar.md](grammar.md)).

### Smaller ones

- **No type from arithmetic:** `let v = a + b` is an error that asks for
  a type, `let v:i64 = a + b`; a literal, a call whose type kelvinc
  sees and `v as T` give one.
- **No default or named arguments:** an overload with fewer parameters
  calls the other, `let greet(name:cstr) { greet(name, 1) }`.
- **No `class`, `protocol`, `throw` or `catch`:** kelvinc reads each as
  a name, and says what it expected instead.
