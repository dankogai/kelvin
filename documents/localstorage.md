# localStorage: `#import <localStorage>`

JS's `localStorage` for a program: text kept by text keys in a file of its own, there again at the next run.

## Synopsis

```swift
#import <localStorage>

let main():int32 {
    var runs:i64 = i64(localStorage.getItem("runs") ?? $"0") + 1
    localStorage.setItem("runs", `${runs}`)                // written to its file at once
    println("run ", runs, ", kept in ", localStorage.path)
    for i in 0..<localStorage.length {
        println(localStorage.key(i))                        // some("runs"), in the order set
    }
    localStorage.removeItem("old")
    return 0
}
```

## Description

`#import <localStorage>` (#491) brings in `localStorage`, a global, as a
browser gives a page one for its origin: Strings by String keys, kept
between runs, in the order set. A program here is the origin: each has
its own file.

- **The methods** are JS's Storage's:
  - `localStorage.getItem(key)` is the value, a `String?`, `none` where
    there is no such key;
  - `localStorage.setItem(key, value)` sets it, replacing what was there;
  - `localStorage.removeItem(key)` removes it, where it is there;
  - `localStorage.clear()` removes them all;
  - `localStorage.length` is how many, an `i64`, and
    `localStorage.key(i)` the key of item `i`, a `String?`, `none` out of
    `0..<length`.
  - A key or a value is text, a `cstr`, or a String by reference, `&s`.
    A number is written as text, `` `${n}` ``, and read back by
    `i64(...)`, as JS's turns it into a string.
- **Its file** is read at its first use, and written at each change, by
  `setItem`, `removeItem` and `clear`: whole, to a file beside it, which
  is renamed over it, so that a reader never sees half of one, and a
  crash loses nothing done.
  - It is JSON ([json.md](json.md)), an object of Strings, written two
    spaces a level; a member that is not a String is left out as it is
    read.
  - `KELVIN_LOCALSTORAGE` in the environment names it; else it is
    `$XDG_DATA_HOME/kelvin/localStorage/<program>.json`, else
    `~/.local/share/kelvin/localStorage/<program>.json`, `<program>` the
    name the program was run by, its directories made as it is written.
  - `localStorage.path` is the file, a String.
  - A program that sets `KELVIN_LOCALSTORAGE` itself does so before its
    first use, which reads the file.
- **Not as a browser's:**
  - Two programs, or two runs at once, of one file are not kept from
    each other: the last to write wins, as no lock is taken.
  - Two threads are not kept from each other either: use it from one.
  - There is no quota, and no `storage` event.
  - A file that cannot be written leaves the items in memory, as they
    were set, and the file as it was.
- **`Storage`** is the struct `localStorage` is, the one there is; its
  methods read and write the global.

## Where it lives

`modules/localStorage.k`, written in Kelvin over `<JSON>`, `<OS>` and
`<IO>`; `make` builds it with `kelvinc --lib` into `localStorage.kh` and
`libklocalStorage`. Its global is freed as the program exits, as a
module's global owners are (#491).

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `localStorage` | `.getItem(key)` | the value, a `String?`; `key` a `cstr` or `&s` |
| | `.setItem(key, value)` | sets it, and writes the file |
| | `.removeItem(key)` | removes it, and writes the file |
| | `.clear()` | removes all, and writes the file |
| | `.length` | how many, an `i64` |
| | `.key(i)` | the key of item `i`, in the order set, a `String?` |
| | `.path` | its file, a String |
