# Task: `async` and `await`

A call run on a thread of its own: `async f(x)` starts it, and `await t` gives its result.

## Synopsis

```swift
let fib(n:int64):int64 { n < 2 ? n : fib(n - 1) + fib(n - 2) }

let main():int32 {
    let a = async fib(30)                  // Task<int64>, running already
    let b = async fib(31)                  // both running now
    println(fib(20))                       // the same fib, called as always
    println(await a + await b)             // 2178309
    return 0
}
```

## Description

`async f(x)` makes a call on a thread of its own (#312) and gives a
`Task<R>` of `f`'s result; `await t` waits for it and gives that value.
The arguments are passed as any call passes them, a value copied and an
owner moved in, so that the two threads share nothing. `f` is an
ordinary function, which may as well be called as always.

- **`async f(x)`** starts the call on a thread of its own, at once, and
  gives a `Task<R>`.
  - `R` is `f`'s result; a function without one gives a `Task`, which
    `await` waits for, as a line of its own.
  - `f` is a Kelvin function or a function value, whose types kelvinc
    sees; a C function, a method and an overload C would choose are
    errors.
  - A block, `async { ... }`, is an error: it would take the names
    around it, which Kelvin does not enclose.
  - It is written in a function.
- **The arguments** are worked out where the call is, and passed as any
  call passes them.
  - A value is copied.
  - An owner moves in (O5), and its name holds nothing afterwards: a
    `String`, a `Bytes`, an `Array`, a `Dictionary`, a `Set`, an `IO`,
    a `Task`, or a struct that holds one. To keep one, pass a copy,
    `async f(s.copy())`.
  - A parameter that is a pointer, a `cstr` or an array is an error:
    the two threads would share what it points to. A function that is
    given a `String` takes its text instead.
  - A global is the program's, shared as C's are, with nothing to keep
    two threads from it at once.
- **`await t`** waits for the thread and gives the value, once.
  - `t` holds nothing afterwards, as a move leaves it, so a second
    `await t` is an error.
  - `await xs[i]` waits for an element of an `Array<Task<T>>`, which
    it empties.
  - `await` of a Task an expression gives waits for it there:
    `await async fib(30)` is `fib(30)` on a thread of its own, worth
    it only where something else is running.
- **A Task is an owner** ([ownership.md](ownership.md)).
  - It is not copied; it moves by `return` and by passing, and `&t`
    borrows it.
  - The end of its block waits for one never awaited, and frees its
    value.
  - `t = async f(x)` waits for the old one first.
  - One given and dropped, as a line of its own, is an error: it would
    be awaited at once.
  - `let t:Task<R> = ...` says what it gives, which the call's must be.
- **kc** reads `async f(x)` and `await t` too (#313), of a Kelvin
  function, kc having no function values ([selfhost/README.md](../selfhost/README.md)).
- **A thread each**: a call is a thread of the system's.
  - One that cannot start, as when too many run, ends the program with
    a message, as running out of memory does.
  - `println` from two threads at once may mix their pieces.

### What each takes and gives

Each line is written as it would be declared, in Kelvin's spelling.

<!-- fragment -->
```swift
async f(x): Task<R>                    // R: f's result; Task where it has none
await t: R                             // waits for t's thread; t holds nothing afterwards
Task<R>, Task                          // an owner, kv_task in C
```

## Where it lives

The prelude. `Task` is runtime/task.k, written in Kelvin, in `libkelvin`, declared by `kelvin_prelude.h`, linked without an import; the threads are POSIX's, which kelvinc links with `-lpthread`. kelvinc makes the call in a function of its own, the thread's, from an environment that holds the arguments and the result.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Task<R>` | `await t` | the value, an `R`, once |
| `Task` | `await t` | nothing: it waits |

A `Task` has no property or method: `await` is what it is for. The
general properties are in [properties.md](properties.md).
