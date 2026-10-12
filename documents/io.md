# IO: stdio as an owner

`IO` is a file, or one of the three standard streams, as an owner (#82):
C's `FILE *`, closed when its block ends if the IO opened it, flushed if
it is `stdin`, `stdout` or `stderr`. Opening and reading a whole file
give a `Result`, with `errno` as the `err`, so `try` passes a failure
up; reading in chunks and in lines are walked by `for`. The ownership
rules are in [ownership.md](ownership.md), Results in
[results.md](results.md).

```kelvin
let count(path:cstr):Result<i64, i32> {
    let f = try IO(path, "r")            // the IO, or return the errno
    var n:i64 = 0
    for line in f.lines { n += 1 }       // each line, a String, without its newline
    return n                              // f closes here
}
let copy(from:cstr, to:cstr):Result<i64, i32> {
    let src = try IO(from, "r")
    let dst = try IO(to, "w")
    var total:i64 = 0
    for chunk in src.read(4096) {        // the next 4096 bytes at most, a Bytes
        dst.write(&chunk)
        total += chunk.count as i64
    }
    return total
}
let f = try IO("log.txt", "a")
f.write("started\n")                      // text
f.write(&name)                            // a borrow of a String or a Bytes
f.write($`${n} items\n`)                  // a String an expression gives, written and freed
f.println("n = ", n, ", half = ", n / 2.0)   // as println, to the file (#83)
f.flush()
let text = try f.string                   // the rest of the file as a String, or errno (EILSEQ if not UTF-8)
let raw = try f.bytes                     // as a Bytes
IO.stderr.write("warning\n")              // never closed; also IO.stdin, IO.stdout
if let err(e) = IO("missing", "r") { println(strerror(e)) }
```

- **Making one:** `IO(path, mode)` opens as `fopen` does, with C's modes
  (`"r"`, `"w"`, `"a"`, `"rb"`, `"r+"`, ...), and gives a
  `Result<IO, i32>`: the IO, or `errno` as `fopen` left it. `path` and
  `mode` are text (a literal, a `cstr`, a `u8^`), a `String` or a
  `Bytes` in a variable. `IO.stdin`, `IO.stdout` and `IO.stderr` are
  the standard streams, also written `IO.stdout()`: an IO that is never
  closed, only flushed, and may be used where it stands,
  `IO.stderr.write("x")`, or bound, `var out = IO.stdout`.
- **An owner:** a variable owns its IO, and its block closes it; `try`,
  `return` and passing move it; `&f` borrows it; it is not copied, so
  `var g = f` is an error, as is `.copy()`. A struct may hold one, and
  then closes it with its other owners; a Result holds the one `IO`
  gives. `f.close()` closes it now, and its block then does nothing;
  it needs the var that owns the IO, as `append` needs a String's,
  since a let bound by `if let` holds a copy, and closing through it
  would close twice: write `r.ok.close()` of the Result.
- **Reading whole:** `f.bytes` is the rest of the file as a `Bytes`, and
  `f.string` as a `String`, each a `Result` with `errno` as the err:
  `EILSEQ` when the bytes are not UTF-8, what `ferror` reports when the
  file cannot be read, as a directory cannot on Linux. Both are of an
  IO in a variable, since the Result they give owns the text.
- **Reading by parts:** `for chunk in f.read(n) { }` gives the next `n`
  bytes at most as a `Bytes`, up to the end; `for line in f.lines { }`
  each line as a `String` without its `\n`, up to the end, and a line
  that is not UTF-8 ends the program with a message. The loop owns the
  one Bytes or String it holds, filled again each time round, and
  `chunk` or `line` is a let that borrows it: copy it to keep it. Both
  are only for `for`; `break`, `continue` and `return` work in the body.
- **Writing:** `f.write(x)` writes text (a literal, a `cstr`, a `u8^`),
  a borrow of a `String` or a `Bytes` (`&s`, or a `String^` held), or
  a String or Bytes an expression gives, which is then freed.
  **`f.print(a, b, ...)`** and **`f.println(...)`** (#83) show up to 16
  values as `print` and `println` do, by their types (numbers, floats
  in their shortest form, `bool`, text, a `String`, a `Bytes`, a
  `uchr` as its character, a struct's `.cstr`), to the IO:
  `IO.stderr.println("warning: ", n)`; see
  [printing.md](printing.md). `f.flush()` flushes. Writing
  to a closed IO ends the program.
- **Lets:** an IO bound by `let`, as `try` and `if let` bind it, still
  reads, writes and flushes: what changes is the file, not the IO.
  Only `close` changes the IO, so it needs a var.
- **In C**, an IO is `kv_io`, a `FILE *` and whether it is owned, in
  libkelvin's runtime/io.c; the standard streams are three statics
  that `IO.stdout` names in place.
- **Not yet:** seeking, `.eof`, reading a single byte or a number, and
  opening with a file descriptor.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `IO(path, mode)` | | a `Result<IO, i32>`: the IO, or errno |
| `IO.stdin`, `IO.stdout`, `IO.stderr` | | the stream, never closed |
| an `IO` | `.bytes` | a `Result<Bytes, i32>`: the rest of the file |
| | `.string` | a `Result<String, i32>`: the same as UTF-8, or `EILSEQ` |
| | `for x in f.read(n) { }` | each next `n` bytes at most, a `Bytes` the loop owns |
| | `for line in f.lines { }` | each line without its newline, a `String` the loop owns |
| | `.write(x)` | writes text, `&s` of a String or a Bytes, or one an expression gives |
| | `.print(a, ...)`, `.println(a, ...)` | as `print` and `println`, to the IO (#83) |
| | `.flush()`, `.close()` | flushes; closes now, through the var that owns it |
| | `.size`, `.typename` | `sizeof`; `IO` |

No `.cstr`, no `==`, no `.copy()`. The general properties are in
[properties.md](properties.md).
