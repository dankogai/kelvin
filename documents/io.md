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
var bare = IO.exec(["/usr/bin/env"], "r", "", ["ONLY=1"], true)   // an environment of that entry alone (#93)
if let ok(p) = ls { for line in p.lines { println(line) } }
f.flush()
let text = try f.string                   // the rest of the file as a String, or errno (EILSEQ if not UTF-8)
let raw = try f.bytes                     // as a Bytes
IO.stderr.write("warning\n")              // never closed; also IO.stdin, IO.stdout
if let err(e) = IO("missing", "r") { var why = IO.strerror(e); println(why) }   // the err's message (#103)
```

- **Making one:** `IO(path, mode)` opens as `fopen` does, with C's modes
  (`"r"`, `"w"`, `"a"`, `"rb"`, `"r+"`, ...), `"r"` when the mode is
  left out, `IO(path)` (#101), and gives a
  `Result<IO, i32>`: the IO, or `errno` as `fopen` left it. `path` and
  `mode` are text (a literal, a `cstr`, a `u8^`), a `String` or a
  `Bytes` in a variable. `IO(fd, mode)` (#86), with a number first,
  opens a file descriptor as `fdopen` does, and owns it: its block
  closes the descriptor too; `f.fd` is an IO's descriptor, an `i32`,
  for C's calls, -1 once closed. `IO.popen(command, mode)` (#87) runs
  a shell command as `popen` does, with `"r"` to read its output or
  `"w"` to write its input, a `Result<IO, i32>`, run as `/bin/sh -c`
  through the same fork and exec as `IO.exec`, so that its pid is
  known (#100); its block, or
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
  entered is an err, as a missing program is. `IO.exec(args, mode,
  dir, env, fresh)` (#93), with `fresh` a `bool`, makes the environment
  from nothing but the entries when it is `true`, `[]` for an empty
  one: the program is then found on that environment's PATH, or the
  system's default when it has none, so a fresh environment names the
  program by its path, or sets PATH. `f.kill(signal)` (#91)
  sends a signal to that process, or to an `IO.popen`'s (#100), `true`
  when it was sent, and `f.pid` is its process id, an `i32`, -1 for
  an IO that is no process. The
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
- **`f.isatty`** (#103) is whether the IO's descriptor is a terminal,
  as C's `isatty` says: `false` for a file, a pipe, a process, a
  closed IO, and a stream that is redirected. **`IO.strerror(code)`**
  is the message for an `err`, a `String`, the same as
  `OS.strerror`, so a program reading a `Result` of `IO(...)` need not
  go to `OS` for it.
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
  that `IO.stdout` names in place. `fdopen`, `fileno`, `pipe`, `fork`,
  `execvp`, `waitpid`, `kill` and `putenv` are POSIX
  and X/Open, which the runtime asks for; a program needs nothing.
- **Not yet:** nothing of what was listed here; see
  [os.md](os.md) for the system around a program.

## Its path, and the OS's work on it

An IO opened by path keeps that path (#101): `f.path` is it as given,
a `cstr`, `""` for a stream or a process, and the work `OS` does on a
path, [os.md](os.md)'s, is done from the IO on its own:

```kelvin
let f = try IO("./notes.txt")                 // a path alone opens for reading
var abs = f.abspath                           // a String: /home/me/notes.txt
println(f.path, " ", abs, " ", f.stat.size)   // ./notes.txt, and the open file's size, no case to unwrap (#104)
let d = try IO(".")                           // a directory opens too
for name in try d.listdir { println(name) }   // its names; d.walk every path under it; d.glob("*.k")
```

- **`f.path`** is the path as given; **`f.abspath`** the absolute path
  with every link followed, a `String`, `""` where the IO has no path
  or the path is gone (#104); **`f.basename`** and **`f.dirname`** its
  parts and **`f.join(name)`** a path under it, each a `String`.
- **`f.stat`** is the `Stat` of the open file itself, through its
  descriptor, straight and no Result (#104): an open descriptor always
  answers, so a file removed or renamed while open still does, and
  `let s = f.stat` or `f.stat.size` reads it without a case. Once the
  IO is closed it is the path's, and all zero where there is none.
  **`f.lstat`** is the path's own, a link's not its target's, and the
  open file's where the path is gone or there is none. **`f.isdir`** and
  **`f.isfile`** are the open file's, as `f.stat` sees it; **`f.islink`**
  and **`f.exists`** are `OS`'s of the path. `OS.stat(path)` stays a
  `Result`: a path is looked up anew at each call, and may be gone.
- **`f.listdir`**, **`f.walk`** and **`f.glob(pattern)`** are `OS`'s
  of the path, a directory's, the pattern under it.
- **`f.chmod(mode)`**, **`f.chown(uid, gid)`** and
  **`f.truncate(size)`** work on the open file itself; **`f.remove()`**,
  **`f.rename(to)`**, **`f.utime(atime, mtime)`** and **`f.touch()`**
  on the path, each 0 or `errno`. After `rename`, `f.path` is the new
  name, so `rename` needs the var that owns the IO, as `close` does. A
  file removed while open stays readable until it is closed.
- An IO with no path, a stream or a process, answers `""`, `false` or
  `ENOENT`.

## What each member takes and gives

Each line is a member as it would be declared, in Kelvin's spelling.
`text` stands for a string literal, a `cstr`, a `u8^`, or a `String`
or a `Bytes` held in a variable; an `i32` that is "0 or `errno`" is 0
on success and otherwise the `errno` C left; a `Result<T, i32>` holds
the `T` or that `errno`. `Stat` is the struct of [os.md](os.md).

```kelvin
IO(path: text, mode: text): Result<IO, i32>        // fopen; "r" when the mode is left out
IO(fd: i32, mode: text): Result<IO, i32>           // fdopen; the IO owns the descriptor
IO.stdin: IO                                        // the streams, never closed, only flushed
IO.stdout: IO
IO.stderr: IO
IO.popen(command: text, mode: text): Result<IO, i32>            // /bin/sh -c command, "r" its output, "w" its input
IO.exec(args: [text], mode: text): Result<IO, i32>              // a program by its arguments, no shell
IO.exec(args: [text], mode: text, dir: text): Result<IO, i32>   // run in a directory, "" for the current one
IO.exec(args: [text], mode: text, dir: text, env: [text]): Result<IO, i32>   // with "NAME=value" entries added
IO.exec(args: [text], mode: text, dir: text, env: [text], fresh: bool): Result<IO, i32>   // true: those entries alone
IO.pipe(): Result<{reader: IO, writer: IO}, i32>  // a pipe's two ends
IO.strerror(code: i32): String                    // the message for an err

f.bytes: Result<Bytes, i32>              // the rest of the file, as bytes
f.string: Result<String, i32>            // the same as UTF-8; EILSEQ when it is not
for chunk in f.read(n: i64) { }          // each next n bytes at most, a Bytes the loop owns
for line in f.lines { }                  // each line without its newline, a String the loop owns
f.byte: u8?                              // the next byte, none at the end
f.write(x: text | &String | &Bytes | String | Bytes)   // text, a borrow, or an owner given, freed after
f.print(a, b, ...)                       // as print, up to 16 values
f.println(a, b, ...)                     // as println
f.flush()
f.close()                                // now; needs the var that owns the IO
f.eof: bool                              // true once a read has met the end
f.isatty: bool                           // its descriptor is a terminal
f.position: i64                          // the offset in bytes, -1 where the stream has none
f.count: i64                             // the length in bytes, -1 where the stream has none
f.seek(offset: i64): bool                // from the start; false where it could not
f.rewind()                               // to the start, the end cleared
f.fd: i32                                // the descriptor, -1 once closed
f.status: i32                            // a process's exit code once closed, else -1
f.signal: i32                            // the signal that ended a process, 0 when none, else -1
f.pid: i32                               // a process's id, -1 for any other IO
f.kill(signal: i32): bool                // to a process; true when sent

f.path: cstr                             // as opened with; "" for a stream, a descriptor or a process
f.abspath: String                        // absolute, every link followed; "" with no path (#104)
f.basename: String                       // after the last /
f.dirname: String                        // before it
f.join(name: text): String               // a path under it
f.stat: Stat                             // of the open file itself, through its descriptor: no Result (#104)
f.lstat: Stat                            // the path's own, a link's; the open file's where the path is gone
f.isdir: bool                            // of the open file, as f.stat sees it
f.isfile: bool
f.islink: bool
f.exists: bool
f.listdir: Result<Array<String>, i32>    // a directory's names, sorted
f.walk: Result<Array<String>, i32>       // every path under it, depth first
f.glob(pattern: text): Result<Array<String>, i32>   // the matches of the pattern under its path
f.chmod(mode: i32): i32                  // on the open file; 0 or errno
f.chown(uid: i32, gid: i32): i32         // on the open file; -1 leaves an id
f.truncate(size: i64): i32               // on the open file
f.remove(): i32                          // the path; the open file stays readable until closed
f.rename(to: text): i32                  // the path, which then follows; needs the var that owns the IO
f.utime(atime: f64, mtime: f64): i32     // the path's times, in seconds since the epoch
f.touch(): i32                           // both now
```

`[text]` for `args` and `env` is a list written in brackets,
`["ls", "-l"]`, or an `Array<cstr>` or `Array<String>` held in a
variable. Where a member gives an owner, a `String`, a `Bytes`, an
`Array` or an `IO`, bind it, and its block frees it; a `Result` or an
Optional holding one is an owner too.

## The structs an IO gives

Two members give a struct with no name, spelled as itself:

- **`IO.pipe()` gives `{reader: IO, writer: IO}`**: `reader` is the
  end to read from and `writer` the end to write to, each an `IO`
  that owns its descriptor. What is written to `writer` is read from
  `reader`, in order, and closing `writer` is the end of `reader`'s
  input; `writer.close()` needs the var, so write `p.ok.writer.close()`
  of the Result. The struct owns both, so a Result holding it closes
  both when its block ends.
- **`OS.mkstemp(prefix)` gives `{io: IO, path: String}`**: `io` is
  the new file, open for reading and writing (`"w+"`) and positioned
  at its start, and `path` its name, the prefix and six random
  characters, in `OS.tmpdir` unless the prefix names a place. The file
  stays until `OS.remove(t.ok.path)`, or `t.ok.io.remove()`; the
  block closes the IO and frees the path.

Both are ordinary untagged structs, so `t.ok.io`, `t.ok.path`,
`p.ok.reader` and `p.ok.writer` are places: methods work on them, and
`.cstr` of the struct shows the IO as `<IO>` and the path as its text.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `IO(path, mode)`, `IO(path)` | | a `Result<IO, i32>`: the IO, or errno; the mode `"r"` when none (#101) |
| `IO(fd, mode)` | | a `Result<IO, i32>` of a descriptor, as `fdopen` gives it (#86) |
| `IO.popen(command, mode)` | | a `Result<IO, i32>` of a shell command's output or input (#87) |
| `IO.exec(args, mode)` | | the same of a program run without the shell, `args` a list or an Array (#90) |
| `IO.exec(args, mode, dir, env)` | | the same, in a directory, with `"NAME=value"` entries added to the environment (#92) |
| `IO.exec(args, mode, dir, env, fresh)` | | the same, with the entries as the whole environment when `fresh` is `true` (#93) |
| `IO.pipe()` | | a `Result<{reader: IO, writer: IO}, i32>`, a pipe's two ends (#87) |
| `IO.stdin`, `IO.stdout`, `IO.stderr` | | the stream, never closed |
| `IO.strerror(code)` | | the message for an `err`, a `String` (#103) |
| an `IO` | `.bytes` | a `Result<Bytes, i32>`: the rest of the file |
| | `.string` | a `Result<String, i32>`: the same as UTF-8, or `EILSEQ` |
| | `for x in f.read(n) { }` | each next `n` bytes at most, a `Bytes` the loop owns |
| | `for line in f.lines { }` | each line without its newline, a `String` the loop owns |
| | `.write(x)` | writes text, `&s` of a String or a Bytes, or one an expression gives |
| | `.print(a, ...)`, `.println(a, ...)` | as `print` and `println`, to the IO (#83) |
| | `.flush()`, `.close()` | flushes; closes now, through the var that owns it |
| | `.byte` | the next byte, a `u8?`, `none` at the end (#85) |
| | `.eof` | `true` once a read has met the end (#84) |
| | `.isatty` | its descriptor is a terminal (#103) |
| | `.position`, `.count` | the offset from the start, and the length, in bytes; -1 where there is none |
| | `.fd` | the file descriptor, an `i32`, -1 once closed (#86) |
| | `.status` | a process's exit code once closed, else -1 (#87) |
| | `.signal` | the signal that ended a process, once closed; 0 when none; else -1 (#89) |
| | `.kill(signal)`, `.pid` | sends a signal to a process `IO.popen` or `IO.exec` started, a `bool`; its pid, -1 for any other IO (#91, #100) |
| | `.path`, `.abspath` | the path as given, a `cstr`; resolved, a `String`, `""` with no path (#101, #104) |
| | `.basename`, `.dirname`, `.join(name)` | the path's parts, a path under it, `String`s |
| | `.stat`, `.lstat` | C's stat of the open file, of the path's own, each a `Stat` straight, no Result (#104) |
| | `.isdir`, `.isfile`, `.islink`, `.exists` | `bool`s: of the open file, of the open file, of the path, of the path |
| | `.listdir`, `.walk`, `.glob(pattern)` | the names, every path under it, the matches, each a `Result<Array<String>, i32>` |
| | `.chmod(mode)`, `.chown(uid, gid)`, `.truncate(size)` | on the open file, 0 or `errno` |
| | `.remove()`, `.rename(to)`, `.utime(atime, mtime)`, `.touch()` | on the path, 0 or `errno`; `rename` needs a var |
| | `.seek(n)`, `.rewind()` | moves to byte `n` from the start, a `bool`; to the start, clearing the end |
| | `.size`, `.typename` | `sizeof`; `IO` |

No `.cstr`, no `==`, no `.copy()`. The general properties are in
[properties.md](properties.md).
