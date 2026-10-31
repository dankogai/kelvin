# IO: stdio as an owner

A file, or a standard stream, as an owner: opened, read, written, and closed when its block ends.

## Synopsis

<!-- fragment -->
```swift
#import <IO>

let count(path:cstr):Result<int64, int32> {
    let f = IO(path, "r")                // the IO, straight (#109)
    if f.error != 0 { return err(f.error) }   // the errno when it did not open, passed up
    var n:int64 = 0
    for line in f.lines { n += 1 }       // each line without its newline, a Result<String, i64> (#406)
    return n                              // f closes here
}
let copy(from:cstr, to:cstr):Result<int64, int32> {
    let src = IO(from, "r")
    let dst = IO(to, "w")
    if src.error != 0 { return err(src.error) }
    if dst.error != 0 { return err(dst.error) }
    var total:int64 = 0
    for chunk in src.read(4096) {        // the next 4096 bytes at most, a Bytes
        dst.write(&chunk)
        total += chunk.count as int64
    }
    return total
}
let f = IO("log.txt", "a")                // straight; f.error is the errno when it did not open (#109)
f.write("started\n")                      // text
f.write(&name)                            // a borrow of a String or a Bytes
f.write($`${n} items\n`)                  // a String an expression gives, written and freed
f.println("n = ", n, ", half = ", n / 2.0)   // as println, to the file (#83)
f.seek(0); println(f.count, " ", f.eof)       // the position: from the start, the length, past the end? (#84)
if let b = f.byte { println(b) }              // the next byte, or none (#85)
for r in f.lines { if let line = r { sum += int64(line) } }   // a number is read from the text (#88)
var ls = IO.popen("ls -l", "r")               // a shell command's output, straight (#87, #110); IO.pipe() a pipe's two ends
var wc = IO.exec(["wc", "-l", path], "r")     // a program's, no shell (#90); wc.error is ENOENT when there is no such program
if wc.error == 0 { wc.kill(15) }              // a signal to it (#91); wc.pid its process id
var ls = IO.exec(["ls"], "r", "/tmp", ["LC_ALL=C"])   // in a directory, with an environment entry (#92)
var bare = IO.exec(["/usr/bin/env"], "r", "", ["ONLY=1"], true)   // an environment of that entry alone (#93)
for r in ls.lines {                           // each line a Result: the String, or where its UTF-8 breaks (#406)
    if let line = r { println(line) } else { println("not UTF-8 at byte ", r.err) }
}
f.flush()
let text = f.string ?? $""                // the rest of the file, a Result<String, i64>: err where the UTF-8 breaks (#406)
let raw = f.bytes                         // as a Bytes, whatever it holds
IO.stderr.write("warning\n")              // never closed; also IO.stdin, IO.stdout
var m = IO("missing", "r")
if m.error != 0 { var why = IO.strerror(m.error); println(why) }   // the error's message (#103)
```

## Description

`IO` is a file, or one of the three standard streams, as an owner (#82):
C's `FILE *`, closed when its block ends if the IO opened it, flushed if
it is `stdin`, `stdout` or `stderr`. Opening and reading a whole file
give a `Result`, with `errno` as the `err`, so `try` passes a failure
up; reading in chunks and in lines are walked by `for`. The ownership
rules are in [ownership.md](ownership.md), Results in
[results.md](results.md). IO is a module: a program writes `#import
<IO>` (#144).

- **Making one:** `IO(path, mode)` opens as `fopen` does, and gives
  the IO straight (#109).
  - `mode` is C's: `"r"`, `"w"`, `"a"`, `"rb"`, `"r+"`, ...; left out,
    it is `"r"`: `IO(path)` (#101).
  - `path` and `mode` are text (a literal, a `cstr`, a `u8^`), or a
    `String` or a `Bytes` in a variable.
  - When the open failed, `f.error` is the `errno` as `fopen` left it,
    0 otherwise.
    - Such an IO is as a closed one: `f.fd` is -1, its path is kept,
      its whole-file reads and its attributes give none.
    - Reading it by `f.lines` or `f.read(n)`, or writing to it, ends
      the program with the path and the reason.
    - Ask `f.error` where a file may be missing; `return err(f.error)`
      passes it up.
- **`IO(fd, mode)`** (#86), with a number first, opens a file descriptor
  as `fdopen` does, and owns it.
  - Its block closes the descriptor too.
  - `EBADF` is its `f.error` when the descriptor is bad.
  - `f.fd` is any IO's descriptor, an `i32`, for C's calls; -1 once
    closed.
- **`IO.popen(command, mode)`** (#87) runs a shell command as `popen`
  does, and gives the IO straight (#110).
  - `"r"` reads its output, `"w"` writes its input.
  - It runs as `/bin/sh -c` through the same fork and exec as
    `IO.exec`, so its pid is known (#100).
  - Its block, or `close()`, waits for the process.
    - `f.status` is then its exit code; -1 before, or for an IO that is
      no process.
    - `f.signal` (#89) is the signal that ended it; 0 when it exited on
      its own; -1 before, or for an IO that is no process. `status` is
      -1 for a process a signal ended.
- **`IO.exec(args, mode)`** (#90) runs a program without the shell, and
  gives the IO straight (#110).
  - `args` is the program and its arguments: a list of text,
    `["ls", "-l"]`, or an `Array` of `cstr` or of `String` in a
    variable. The program is found on the PATH as `execvp` finds it.
  - `mode` is `"r"` to read its output or `"w"` to write its input.
  - What the exec itself failed with is `f.error`, `ENOENT` for a
    program not found; the IO is then as one that did not open, and
    `f.pid` is -1.
  - Its block, or `close()`, waits for it; `status` and `signal` are
    then as a `popen`'s.
  - `IO.exec(args, mode, dir)` and `IO.exec(args, mode, dir, env)`
    (#92) run it in a directory, with entries added to the environment.
    - `dir` is text or a String; `""` is the current directory.
    - `env` holds `"NAME=value"` entries, a list or an Array of `cstr`
      or of `String` in a variable, added to the parent's environment
      or replacing the ones it has.
    - A directory that cannot be entered is `f.error` too, as a missing
      program is.
  - `IO.exec(args, mode, dir, env, fresh)` (#93), with `fresh` a `bool`,
    makes the environment from nothing but the entries when it is
    `true`; `[]` is an empty one.
    - The program is then found on that environment's PATH, or the
      system's default when it has none: name it by its path, or set
      PATH.
- **`f.kill(signal)`** (#91) sends a signal to the process `IO.exec` or
  `IO.popen` started (#100).
  - `true` when it was sent.
  - `f.pid` is the process id, an `i32`; -1 for an IO that is no
    process.
  - The signal numbers are C's, `f.kill(15)`, or `SIGTERM` with
    `#import <signal.h> as C`.
  - `close()` then waits, and `f.signal` says which signal ended it.
- **`IO.pipe()`** gives `{reader: IO, writer: IO}` straight (#110): a
  pipe's two ends, each an IO that owns its descriptor.
  - `p.writer.close()` ends what the reader reads.
  - Both ends carry the `error` of a pipe that could not be made.
- **`IO.stdin`, `IO.stdout` and `IO.stderr`** are the standard streams,
  also written `IO.stdout()`.
  - Never closed, only flushed.
  - Used where they stand, `IO.stderr.write("x")`, or bound,
    `var out = IO.stdout`.
- **An owner:** a variable owns its IO, and its block closes it.
  - `return` and passing move it; `&f` borrows it.
  - It is not copied: `var g = f` is an error, and so is `.copy()`.
  - A struct may hold one, and then closes it with its other owners.
  - `f.close()` closes it now, and its block then does nothing.
    - It needs the var that owns the IO, as `append` needs a String's:
      a let, as `if let` binds one, holds a copy, and closing through
      it would close twice.
- **Reading whole:** `f.bytes` is the rest of the file as a `Bytes`,
  straight and no Result (#107), since the file was there to open.
  - `f.string` (#406) is the same as a `Result<String, i64>`, as
    `b.string()` is (#405): `ok`, the String, or `err(at)`, `at` the
    offset in what was read where the UTF-8 breaks.
    - The bytes are read either way: read `f.bytes` to keep them.
    - `f.string ?? $""`, `try f.string` in a function whose `err` is an
      `i64`, `if let s = f.string`; see [results.md](results.md).
  - A stream that stops answering, as a directory does on Linux, gives
    what was read before; a closed IO gives none.
  - Both are of an IO in a variable, since what they give is owned,
    and is bound as any owner is.
- **Reading by parts:** `for chunk in f.read(n) { }` and
  `for line in f.lines { }`.
  - `f.read(n)` gives the next `n` bytes at most as a `Bytes`, up to the
    end.
  - `f.lines` gives each line without its `\n`, up to the end, as a
    `Result<String, i64>` (#406): `ok`, the String, or `err(at)`, `at`
    the offset in the line where its UTF-8 breaks; the next line is
    read as any other.
    - `if let line = r` takes the String, `r.err` the offset; `r.ok`
      ends the program on a line that is not UTF-8.
    - `for line:String in f.lines` is an error that names the Result.
  - The loop owns the one Bytes or String it holds, filled again each
    time round; `chunk` or `line` is a let that borrows it: copy it to
    keep it.
  - Both are only for `for`; `break`, `continue` and `return` work in
    the body.
- **Writing:** `f.write(x)` writes `x`.
  - `x` is text (a literal, a `cstr`, a `u8^`), a borrow of a `String`
    or a `Bytes` (`&s`, or a `String^` held), or a String or Bytes an
    expression gives, which is then freed.
  - `f.print(a, b, ...)` and `f.println(...)` (#83) show up to 16 values
    as `print` and `println` do, to the IO:
    `IO.stderr.println("warning: ", n)`; see [printing.md](printing.md).
    - Each by its type: numbers, floats with every digit (#259), `bool`,
      text, a `String`, a `Bytes`, a `uchr` as its character, a struct's
      `.cstr`.
  - `f.flush()` flushes.
  - Writing to a closed IO ends the program.
- **`f.isatty`** (#103) is whether the IO's descriptor is a terminal, as
  C's `isatty` says.
  - `false` for a file, a pipe, a process, a closed IO, and a stream
    that is redirected.
- **`IO.strerror(code)`** is the message for an `error`, a `String`, the
  same as `OS.strerror`, so a program reading `f.error` need not go to
  `OS` for it.
- **The position** (#84), in bytes from the start.
  - `f.position` is the offset, an `i64`; `f.count` the file's length;
    both -1 where the stream has none, as a pipe.
  - `f.seek(n)` moves to byte `n`, and is `true` when it could;
    `f.seek(f.position + k)` and `f.seek(f.count - k)` move elsewhere.
  - `f.rewind()` moves to the start and clears the end.
  - `f.eof` is `true` once a read has met the end, as C's `feof` is: it
    is false before the first read past it, so read, then test.
- **A byte at a time** (#85): `f.byte` is the next byte, a `u8?`,
  `none` at the end.
- **Numbers** are read from the text (#88), with the converters of
  [integers.md](integers.md), which take a String as they take a
  `cstr`.
  - A line: `for r in f.lines { if let line = r { sum += i64(line) } }`.
  - The whole file: `var text = f.string ?? $""; i64(text)`.
  - `f.i64` is an error that says so. C's `scanf` reads no number for
    Kelvin: it skips what it cannot read and leaves the stream where it
    stopped, which no program should have to reason about.
- **Lets:** an IO bound by `let` still reads, writes and flushes: what
  changes is the file, not the IO. Only `close` and `rename` change the
  IO, so they need a var.
- **Not yet:** nothing of what was listed here; see [os.md](os.md) for
  the system around a program.

### Its path, and the OS's work on it

An IO opened by path keeps that path (#101): `f.path` is it as given,
a `cstr`, `""` for a stream or a process, and the work `OS` does on a
path, [os.md](os.md)'s, is done from the IO on its own:

```swift
#import <IO>
let f = IO("./notes.txt")                     // a path alone opens for reading
var abs = f.abspath                           // a String: /home/me/notes.txt
println(f.path, " ", abs, " ", f.stat.size)   // ./notes.txt, and the open file's size, no case to unwrap (#104)
let d = IO(".")                               // a directory opens too
var names = d.listdir                         // its names, an Array straight (#106); d.walk every path under it; d.glob("*.k")
for name in names { println(name) }
```

- **`f.path`** is the path as given, a `cstr`; `""` for a stream, a
  descriptor or a process.
- **`f.abspath`** is the absolute path with every link followed, a
  `String` (#104).
  - Of the path; where that is gone or there is none, of the open
    descriptor as the system names it (#105).
    - A file renamed behind the IO answers by its new name, a removed
      one by the name it had, an IO opened from a descriptor by the
      file's.
    - Else the last name it found (#195), the name it opened as until
      another is found, and the new one after `f.rename` (#196).
      - FreeBSD names no removed file, so a removed one answers by it
        there.
  - `""` where neither answers, as of a pipe or a closed IO.
- **`f.basename`** and **`f.dirname`** are the path's parts, and
  **`f.join(name)`** a path under it, each a `String`.
- **`f.stat`** is the `Stat` of the open file itself, through its
  descriptor, straight and no Result (#104).
  - An open descriptor always answers, so a file removed or renamed
    while open still does: `let s = f.stat`, or `f.stat.size`, reads it
    without a case.
  - Once the IO is closed it is the path's, and all zero where there
    is none.
  - **`f.lstat`** is the path's own, a link's and not its target's; the
    open file's where the path is gone or there is none.
  - **`f.isdir`** and **`f.isfile`** are the open file's, as `f.stat`
    sees it; **`f.islink`** and **`f.exists`** are `OS`'s of the path.
  - `OS.stat(path)` stays a `Result`: a path is looked up anew at each
    call, and may be gone.
- **`f.listdir`**, **`f.walk`** and **`f.glob(pattern)`** are `OS`'s of
  the directory: its names, every path under it, the pattern's matches
  under it, each an `Array<String>` straight and no Result (#106),
  since the directory was there to open.
  - Of the path while it is there; else of the descriptor's name as
    `f.abspath` finds it (#105), so a directory renamed behind the IO
    answers by its new name, with absolute paths.
  - An IO that is no directory one can read, or that nothing names,
    gives none.
  - An Array an expression gives may be used where it is, held until
    the expression is done (#187): `for n in d.listdir { }`.
- **The operations** each give a `bool`, true when done, as `seek` and
  `kill` do (#108), and no `errno`: `OS`'s of the same path tell why.
  - **`f.chmod(mode)`**, **`f.chown(uid, gid)`**, **`f.truncate(size)`**,
    **`f.utime(atime, mtime)`** and **`f.touch()`** work on the open
    file itself, through its descriptor, so they work on a file renamed
    or removed behind the IO.
  - **`f.remove()`** and **`f.rename(to)`** work by the path while it is
    there, else by the descriptor's name (#105).
    - After `rename`, `f.path` is the new name, so `rename` needs the
      var that owns the IO, as `close` does.
    - A file removed while open stays readable until it is closed.
- An IO with no path, a stream or a process, answers `""`, `false` or
  none.

### What each member takes and gives

Each line is a member as it would be declared, in Kelvin's spelling.
`text` stands for a string literal, a `cstr`, a `u8^`, or a `String`
or a `Bytes` held in a variable; an `i32` that is "0 or `errno`" is 0
on success and otherwise the `errno` C left; a `Result<T, i32>` holds
the `T` or that `errno`. `Stat` is the struct of [os.md](os.md).

<!-- fragment -->
```swift
IO(path: text, mode: text): IO                     // fopen, straight; "r" when the mode is left out; f.error when it did not open (#109)
IO(fd: int32, mode: text): IO                        // fdopen; the IO owns the descriptor
IO.stdin: IO                                        // the streams, never closed, only flushed
IO.stdout: IO
IO.stderr: IO
IO.popen(command: text, mode: text): IO            // /bin/sh -c command, "r" its output, "w" its input; straight, f.error when it could not start (#110)
IO.exec(args: [text], mode: text): IO              // a program by its arguments, no shell; f.error ENOENT when there is none
IO.exec(args: [text], mode: text, dir: text): IO   // run in a directory, "" for the current one
IO.exec(args: [text], mode: text, dir: text, env: [text]): IO   // with "NAME=value" entries added
IO.exec(args: [text], mode: text, dir: text, env: [text], fresh: bool): IO   // true: those entries alone
IO.pipe(): {reader: IO, writer: IO}                // a pipe's two ends; both carry the error of a pipe not made
IO.strerror(code: int32): String                    // the message for an err

f.bytes: Bytes                           // the rest of the file, straight (#107)
f.string: Result<String, int64>          // the same as UTF-8, or err where it breaks (#406)
for chunk in f.read(n: int64) { }          // each next n bytes at most, a Bytes the loop owns
for line in f.lines { }                  // each line without its newline, a Result<String, int64> the loop owns (#406)
f.byte: uint8?                              // the next byte, none at the end
f.write(x: text | &String | &Bytes | String | Bytes)   // text, a borrow, or an owner given, freed after
f.print(a, b, ...)                       // as print, up to 16 values
f.println(a, b, ...)                     // as println
f.flush()
f.close()                                // now; needs the var that owns the IO
f.eof: bool                              // true once a read has met the end
f.isatty: bool                           // its descriptor is a terminal
f.position: int64                          // the offset in bytes, -1 where the stream has none
f.count: int64                             // the length in bytes, -1 where the stream has none
f.seek(offset: int64): bool                // from the start; false where it could not
f.rewind()                               // to the start, the end cleared
f.fd: int32                                // the descriptor, -1 once closed
f.error: int32                             // the errno of an open that failed, 0 otherwise (#109)
f.status: int32                            // a process's exit code once closed, else -1
f.signal: int32                            // the signal that ended a process, 0 when none, else -1
f.pid: int32                               // a process's id, -1 for any other IO
f.kill(signal: int32): bool                // to a process; true when sent

f.path: cstr                             // as opened with; "" for a stream, a descriptor or a process
f.abspath: String                        // absolute, every link followed; the descriptor's where the path is gone; else the last found, from the open on (#104, #105, #195, #196)
f.basename: String                       // after the last /
f.dirname: String                        // before it
f.join(name: text): String               // a path under it
f.stat: Stat                             // of the open file itself, through its descriptor: no Result (#104)
f.lstat: Stat                            // the path's own, a link's; the open file's where the path is gone
f.isdir: bool                            // of the open file, as f.stat sees it
f.isfile: bool
f.islink: bool
f.exists: bool
f.listdir: Array<String>                 // a directory's names, sorted; none where it is no directory (#106)
f.walk: Array<String>                    // every path under it, depth first
f.glob(pattern: text): Array<String>     // the matches of the pattern under it
f.chmod(mode: int32): bool                 // on the open file; true when done (#108)
f.chown(uid: int32, gid: int32): bool        // on the open file; -1 leaves an id
f.truncate(size: int64): bool              // on the open file
f.remove(): bool                         // the path, else the descriptor's name; the open file stays readable until closed
f.rename(to: text): bool                 // the same, and the path then follows; needs the var that owns the IO
f.utime(atime: float64, mtime: float64): bool    // the open file's times, in seconds since the epoch
f.touch(): bool                          // both now
```

`[text]` for `args` and `env` is a list written in brackets,
`["ls", "-l"]`, or an `Array<cstr>` or `Array<String>` held in a
variable. Where a member gives an owner, a `String`, a `Bytes`, an
`Array` or an `IO`, bind it, and its block frees it; a `Result` or an
Optional holding one is an owner too.

### The structs an IO gives

Two members give a struct with no name, spelled as itself:

- **`IO.pipe()` gives `{reader: IO, writer: IO}`**: `reader` is the
  end to read from and `writer` the end to write to, each an `IO`
  that owns its descriptor. What is written to `writer` is read from
  `reader`, in order, and closing `writer` is the end of `reader`'s
  input; `writer.close()` needs the var, so write `p.writer.close()`
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

## Where it lives

A module, `#import <IO>` (#143, [modules.md](modules.md)). An IO's functions are `libkIO`, built from runtime/io.c and declared by `kIO.h`, which `modules/IO.kh` brings in and links; it is built on OS, so `#import <IO>` brings `OS` and `SYS` in too. A program needs no `#import <stdio.h>`. Without the import, `IO` is an error that says to write it.

- **In C**, an IO is `kv_io`, a `FILE *` and whether it is owned, in
  libkelvin's runtime/io.c.
  - `abspath` of a descriptor is macOS's `F_GETPATH`, Linux's
    `/proc/self/fd` or FreeBSD's `F_KINFO` (#192), `""` elsewhere.
    - FreeBSD names no removed file, so the IO keeps the last name
      `abspath` found, from the open on (#195, #196).
  - The standard streams are three statics that `IO.stdout` names in
    place.
  - `fdopen`, `fileno`, `pipe`, `fork`, `execvp`, `waitpid`, `kill` and
    `putenv` are POSIX and X/Open, which the runtime asks for; a program
    needs nothing.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `IO(path, mode)`, `IO(path)` | | the IO, straight; `f.error` the errno when it did not open; the mode `"r"` when none (#101, #109) |
| `IO(fd, mode)` | | the same of a descriptor, as `fdopen` gives it (#86) |
| `IO.popen(command, mode)` | | the IO of a shell command's output or input, straight, `f.error` when it could not start (#87, #110) |
| `IO.exec(args, mode)` | | the same of a program run without the shell, `args` a list or an Array (#90) |
| `IO.exec(args, mode, dir, env)` | | the same, in a directory, with `"NAME=value"` entries added to the environment (#92) |
| `IO.exec(args, mode, dir, env, fresh)` | | the same, with the entries as the whole environment when `fresh` is `true` (#93) |
| `IO.pipe()` | | `{reader: IO, writer: IO}`, a pipe's two ends, straight (#87, #110) |
| `IO.stdin`, `IO.stdout`, `IO.stderr` | | the stream, never closed |
| `IO.strerror(code)` | | the message for an `err`, a `String` (#103) |
| an `IO` | `.bytes` | a `Bytes`: the rest of the file, straight (#107) |
| | `.string` | a `Result<String, i64>`: the same as UTF-8, or `err(at)` where it breaks (#406) |
| | `for x in f.read(n) { }` | each next `n` bytes at most, a `Bytes` the loop owns |
| | `for line in f.lines { }` | each line without its newline, a `Result<String, i64>` the loop owns: `err(at)` where its UTF-8 breaks (#406) |
| | `.write(x)` | writes text, `&s` of a String or a Bytes, or one an expression gives |
| | `.print(a, ...)`, `.println(a, ...)` | as `print` and `println`, to the IO (#83) |
| | `.flush()`, `.close()` | flushes; closes now, through the var that owns it |
| | `.byte` | the next byte, a `u8?`, `none` at the end (#85) |
| | `.eof` | `true` once a read has met the end (#84) |
| | `.isatty` | its descriptor is a terminal (#103) |
| | `.position`, `.count` | the offset from the start, and the length, in bytes; -1 where there is none |
| | `.fd` | the file descriptor, an `i32`, -1 once closed (#86) |
| | `.error` | the errno of an open that failed, 0 otherwise (#109) |
| | `.status` | a process's exit code once closed, else -1 (#87) |
| | `.signal` | the signal that ended a process, once closed; 0 when none; else -1 (#89) |
| | `.kill(signal)`, `.pid` | sends a signal to a process `IO.popen` or `IO.exec` started, a `bool`; its pid, -1 for any other IO (#91, #100) |
| | `.path`, `.abspath` | the path as given, a `cstr`; resolved, a `String`, the descriptor's where the path is gone, else the last it found, from the open on (#101, #104, #105, #195, #196) |
| | `.basename`, `.dirname`, `.join(name)` | the path's parts, a path under it, `String`s |
| | `.stat`, `.lstat` | C's stat of the open file, of the path's own, each a `Stat` straight, no Result (#104) |
| | `.isdir`, `.isfile`, `.islink`, `.exists` | `bool`s: of the open file, of the open file, of the path, of the path |
| | `.listdir`, `.walk`, `.glob(pattern)` | the names, every path under it, the matches, each an `Array<String>` straight, none where it is no directory (#106) |
| | `.chmod(mode)`, `.chown(uid, gid)`, `.truncate(size)`, `.utime(atime, mtime)`, `.touch()` | on the open file, a `bool`, true when done (#108) |
| | `.remove()`, `.rename(to)` | by the path, else the descriptor's name, a `bool`; `rename` needs a var |
| | `.seek(n)`, `.rewind()` | moves to byte `n` from the start, a `bool`; to the start, clearing the end |
| | `.size`, `.typename` | `sizeof`; `IO` |

No `.cstr`, no `==`, no `.copy()`. The general properties are in
[properties.md](properties.md).
