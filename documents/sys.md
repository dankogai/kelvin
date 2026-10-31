# SYS: the program

The program itself: its arguments, its platform and its exit.

## Synopsis

```swift
let main():int32 {
    var args = SYS.argv                     // Array<cstr>: the program and its arguments
    if args.count < 2 { println("usage: ", args[0], " name"); SYS.exit(2) }
    println("hello, ", args[1], " on ", SYS.platform)   // macos, linux, ...
    return 0
}
```

## Description

`SYS` is the program itself (#94), after Python's `sys`: its arguments,
its platform and its exit. It is the prelude's (#302), with no import;
the system around the program is `OS`, a module: [os.md](os.md).

- **The prelude's** (#302): `SYS` needs no import, where it came with
  `OS` (#145); `main` gives it the program's arguments.

- **`SYS.argv`** is the program's arguments, `argv[0]` the program, as
  an `Array<cstr>` made from C's `argv`: an owner, so bind it.
  - It is there whether or not `main` declares `argc` and `argv`,
    since C's `main` always takes them for it.
- **`SYS.exit(code)`** flushes every stream and ends the program with
  the code, as C's `exit` does.
  - What follows it never runs, and no block ends, so the owners alive
    at that point are not freed and no file is closed by Kelvin.
  - The system reclaims them, as it does when `main` returns, but a
    file written through an IO is flushed only because every stream
    is.
- **`SYS.platform`** is a `cstr`: `"macos"`, `"linux"`, `"freebsd"`,
  `"openbsd"`, `"netbsd"`, `"windows"` or `"unknown"`, decided when
  the runtime was built.

### What each member takes and gives

Each line is a member as it would be declared, in Kelvin's spelling.

<!-- fragment -->
```swift
SYS.argv: Array<cstr>                    // the program and its arguments; an owner, bind it
SYS.exit(code: int32)                      // ends the program; no value
SYS.platform: cstr                       // "macos", "linux", "freebsd", "openbsd", "netbsd", "windows", "unknown"
```

`SYS.platform` is a borrow of text the runtime keeps for the whole
program: a `cstr` that needs no copy.

## Where it lives

The prelude. `SYS` is runtime/sys.c in `libkelvin`, declared by `kelvin_prelude.h`, linked without an import; `main` gives it the program's arguments where the program names `SYS` or imports `OS`. It came with `OS`, a module, from #145 until #302.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `SYS` | `.argv` | the arguments, an `Array<cstr>` |
| | `.exit(code)` | ends the program |
| | `.platform` | `"macos"`, `"linux"`, ..., a `cstr` |

`SYS` is no value: it is only written before `.`. The general
properties are in [properties.md](properties.md).
