# IO: stdio as an owner

`IO` is a file, or one of the three standard streams, as an owner (#82):
C's `FILE *`, closed when its block ends if the IO opened it, flushed if
it is `stdin`, `stdout` or `stderr`. Opening and reading a whole file
give a `Result`, with `errno` as the `err`, so `try` passes a failure
up; reading in chunks and in lines are walked by `for`. The ownership
rules are in [ownership.md](ownership.md), Results in
[results.md](results.md).

**Where it lives:** the prelude. An IO's functions are in `libkelvin`'s runtime/io.c, declared by `kelvin_prelude.h` and linked without an import; a program needs no `#import <stdio.h>`.

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
f.seek(0); println(f.count, " ", f.eof)       // the position: from the start, the length, past the end? (#84)
if let b = f.byte { println(b) }              // the next byte, or none (#85)
for line in f.lines { sum += i64(line) }      // a number is read from the text (#88)
var ls = IO.popen("ls -l", "r")               // a shell command's output (#87); IO.pipe() a pipe's two ends
var wc = IO.exec(["wc", "-l", path], "r")     // a program's, no shell (#90)
if let ok(p) = wc { p.kill(15) }              // a signal to it (#91); p.pid its process id
var ls = IO.exec(["ls"], "r", "/tmp", ["LC_ALL=C"])   // in a directory, with an environment entry (#92)
if let ok(p) = ls { for line in p.lines { println(line) } }
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
  `Bytes` in a variable. `IO(fd, mode)` (#86), with a number first,
  opens a file descriptor as `fdopen` does, and owns it: its block
  closes the descriptor too; `f.fd` is an IO's descriptor, an `i32`,
  for C's calls, -1 once closed. `IO.popen(command, mode)` (#87) runs
  a shell command as `popen` does, with `"r"` to read its output or
  `"w"` to write its input, a `Result<IO, i32>`; its block, or
  `close()`, waits for the process, and `f.status` is then its exit
  code, -1 before, or for an IO that is no process; `f.signal` (#89)
  is the signal that ended it, 0 when it exited on its own, -1 before
  or for an IO that is no process, and `status` is -1 for a process a
  signal ended. `IO.exec(args, mode)` (#90) runs a program without the
  shell: `args` is the program and its arguments, a list of text,
  `["ls", "-l"]`, or an `Array` of `cstr` or of `String` in a variable,
  the program found on the PATH as `execvp` finds it; `mode` is `"r"`
  to read its output or `"w"` to write its input, a `Result<IO, i32>`,
  with what the exec itself failed with as the err, `ENOENT` for a
  program not found. Its block, or `close()`, waits for it, and
  `status` and `signal` are then as a `popen`'s. `IO.exec(args, mode,
  dir)` and `IO.exec(args, mode, dir, env)` (#92) run it in the
  directory `dir`, text or a String, `""` for the current one, and
  with the entries of `env`, `"NAME=value"` each, a list or an Array of
  `cstr` or of `String` in a variable, added to the parent's
  environment, or replacing those it has; a directory that cannot be
  entered is an err, as a missing program is. `f.kill(signal)` (#91)
  sends a signal to that process, `true` when it was sent, and `f.pid`
  is its process id, an `i32`; a `popen`'s child has no pid C knows,
  so there `kill` is `false` and `pid` is -1, as for any other IO. The
  signal numbers are C's, `f.kill(15)`, or `SIGTERM` with
  `#import <signal.h> as C`; `close()` then waits, and `f.signal` says
  which ended it. `IO.pipe()` gives
  a `Result<{reader: IO, writer: IO}, i32>`: a pipe's two ends, each an
  IO that owns its descriptor, so `p.ok.writer.close()` ends what the
  reader reads. `IO.stdin`, `IO.stdout` and `IO.stderr` are
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
- **The position** (#84): `f.position` is the offset from the start in
  bytes, an `i64`, and `f.count` the file's length, both -1 where the
  stream has none, as a pipe; `f.seek(n)` moves to byte `n` from the
  start, and is `true` when it could; `f.rewind()` moves to the start
  and clears the end; `f.eof` is `true` once a read has met the end, as
  C's `feof` is, so it is false before the first read past it: read,
  then test. A position elsewhere is `f.seek(f.position + k)` or
  `f.seek(f.count - k)`.
- **A byte at a time** (#85): `f.byte` is the next byte, a `u8?`,
  `none` at the end. **Numbers** are read from the text (#88): a line,
  `for line in f.lines { sum += i64(line) }`, or the whole file,
  `i64(try f.string)`, with the converters of
  [integers.md](integers.md), which take a String as they take a
  `cstr`; `f.i64` is an error that says so. C's `scanf` reads no number
  for Kelvin: it skips what it cannot read and leaves the stream where
  it stopped, which no program should have to reason about.
- **Lets:** an IO bound by `let`, as `try` and `if let` bind it, still
  reads, writes and flushes: what changes is the file, not the IO.
  Only `close` changes the IO, so it needs a var.
- **In C**, an IO is `kv_io`, a `FILE *` and whether it is owned, in
  libkelvin's runtime/io.c; the standard streams are three statics
  that `IO.stdout` names in place. `fdopen`, `fileno`, `popen`,
  `pipe`, `fork`, `execvp` and `waitpid` are POSIX, which the runtime
  asks for; a program needs nothing.
- **Not yet:** a `popen`'s pid, which C does not give, and an
  environment made from nothing rather than the parent's.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `IO(path, mode)` | | a `Result<IO, i32>`: the IO, or errno |
| `IO(fd, mode)` | | a `Result<IO, i32>` of a descriptor, as `fdopen` gives it (#86) |
| `IO.popen(command, mode)` | | a `Result<IO, i32>` of a shell command's output or input (#87) |
| `IO.exec(args, mode)` | | the same of a program run without the shell, `args` a list or an Array (#90) |
| `IO.exec(args, mode, dir, env)` | | the same, in a directory, with `"NAME=value"` entries added to the environment (#92) |
| `IO.pipe()` | | a `Result<{reader: IO, writer: IO}, i32>`, a pipe's two ends (#87) |
| `IO.stdin`, `IO.stdout`, `IO.stderr` | | the stream, never closed |
| an `IO` | `.bytes` | a `Result<Bytes, i32>`: the rest of the file |
| | `.string` | a `Result<String, i32>`: the same as UTF-8, or `EILSEQ` |
| | `for x in f.read(n) { }` | each next `n` bytes at most, a `Bytes` the loop owns |
| | `for line in f.lines { }` | each line without its newline, a `String` the loop owns |
| | `.write(x)` | writes text, `&s` of a String or a Bytes, or one an expression gives |
| | `.print(a, ...)`, `.println(a, ...)` | as `print` and `println`, to the IO (#83) |
| | `.flush()`, `.close()` | flushes; closes now, through the var that owns it |
| | `.byte` | the next byte, a `u8?`, `none` at the end (#85) |
| | `.eof` | `true` once a read has met the end (#84) |
| | `.position`, `.count` | the offset from the start, and the length, in bytes; -1 where there is none |
| | `.fd` | the file descriptor, an `i32`, -1 once closed (#86) |
| | `.status` | a process's exit code once closed, else -1 (#87) |
| | `.signal` | the signal that ended a process, once closed; 0 when none; else -1 (#89) |
| | `.kill(signal)`, `.pid` | sends a signal to a process `IO.exec` started, a `bool`; its pid, -1 for any other IO (#91) |
| | `.seek(n)`, `.rewind()` | moves to byte `n` from the start, a `bool`; to the start, clearing the end |
| | `.size`, `.typename` | `sizeof`; `IO` |

No `.cstr`, no `==`, no `.copy()`. The general properties are in
[properties.md](properties.md).
