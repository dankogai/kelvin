# OS and SYS: the system, and the program

`OS` is the system around the program and `SYS` the program itself,
as the prelude's namespaces (#94), after Python's `os` and `sys`, with
no import: `OS.cwd`, `OS.listdir(path)`, `SYS.argv`. Each is C's call
underneath, and gives what C gives, Kelvinized: a `bool`, an `i32`
that is 0 or `errno`, an Optional, or a Result with `errno` as the err,
so `try` passes a failure up. Files themselves are [io.md](io.md)'s.

**Where it lives:** the prelude. `OS` and `SYS` are `libkelvin`'s runtime/os.c, declared by `kelvin_prelude.h` and linked without an import; the calls underneath are POSIX, which the runtime asks for.

```kelvin
let main():i32 {
    var args = SYS.argv                     // Array<cstr>: the program and its arguments
    if args.count < 2 { IO.stderr.println("usage: ", args[0], " dir"); SYS.exit(2) }
    let dir := args[1]
    if !OS.isdir(dir) { println(dir, " is no directory"); return 1 }
    var names = OS.listdir(dir)             // Result<Array<String>, i32>, sorted
    if let ok(ns) = names { for n in ns { println(n) } }
    if let some(home) = OS.env("HOME") { println(home) }   // cstr?: none when unset
    println(SYS.platform, " ", OS.pid)      // macos, linux, ...; the process id
    return 0
}
```

## `SYS`: the program

- **`SYS.argv`** is the program's arguments, `argv[0]` the program, as
  an `Array<cstr>` made from C's `argv`: an owner, so bind it. It is
  there whether or not `main` declares `argc` and `argv`, since C's
  `main` always takes them for it.
- **`SYS.exit(code)`** flushes every stream and ends the program with
  the code, as C's `exit` does; what follows it never runs, and no
  block ends, so the owners alive at that point are not freed and no
  file is closed by Kelvin: the system reclaims them, as it does when
  `main` returns, but a file written through an IO is flushed only
  because every stream is.
- **`SYS.platform`** is a `cstr`: `"macos"`, `"linux"`, `"freebsd"`,
  `"openbsd"`, `"netbsd"`, `"windows"` or `"unknown"`, decided when
  the runtime was built.

## `OS`: the system around it

- **`OS.cwd`** is the working directory, a `Result<String, i32>`;
  **`OS.chdir(path)`** moves to one, 0 or `errno`.
- **`OS.env(name)`** is an environment variable's value, a `cstr?`,
  `none` when it is unset; **`OS.setenv(name, value)`** sets one,
  **`OS.unsetenv(name)`** removes it, each 0 or `errno`.
- **`OS.exists(path)`**, **`OS.isdir(path)`** and **`OS.isfile(path)`**
  are `bool`s: whether something is there, a directory, a regular
  file.
- **`OS.remove(path)`** removes a file or an empty directory,
  **`OS.rename(from, to)`** renames, **`OS.mkdir(path)`** makes a
  directory (mode 0777, as the umask leaves it), **`OS.rmdir(path)`**
  removes an empty one, each 0 or `errno`.
- **`OS.listdir(path)`** is the names in a directory, `.` and `..`
  left out, sorted by their bytes, a `Result<Array<String>, i32>`;
  a name that is not UTF-8 ends the program, as a String made of it
  would.
- **`OS.stat(path)`** and **`OS.lstat(path)`** (#95) are what C's
  `stat` and `lstat` give, a `Result<{dev: i64, ino: i64, mode: i32,
  nlink: i64, uid: i32, gid: i32, size: i64, atime: f64, mtime: f64,
  ctime: f64, isdir: bool, isfile: bool, islink: bool}, i32>`: `lstat`
  of a symbolic link is the link's own, `stat` its target's; the
  times are seconds since the epoch, `mode` C's bits, and `isdir`,
  `isfile` and `islink` read off it. `OS.islink(path)` is the `bool`
  alone.
- **Links and the rest of a file** (#95): `OS.symlink(target, path)`
  makes a symbolic link, `OS.readlink(path)` reads one, a
  `Result<String, i32>`, `OS.link(from, to)` makes a hard link,
  `OS.unlink(path)` removes a file, as `remove` does, `OS.chmod(path,
  mode)` sets C's mode bits, an integer such as `0644` (C's octal),
  `OS.truncate(path, size)` cuts or extends, `OS.makedirs(path)` makes
  every directory on the way, as `mkdir -p` does, and
  `OS.realpath(path)` is the absolute path with every link followed,
  a `Result<String, i32>`; each `i32` is 0 or `errno`.
- **Paths as text** (#95): `OS.basename(path)` and `OS.dirname(path)`
  are the last part and what is before it, as Python's `os.path` has
  them, so `basename("a/b/")` is `""` and `dirname("a")` is `""`,
  `dirname("/a")` `"/"`; `OS.join(a, b)` joins with one `/`, and is
  `b` when `b` is absolute; each a new `String`.
- **The process and the user** (#95): `OS.ppid`, `OS.uid` and
  `OS.gid` are the parent's id and the user's and group's ids;
  `OS.user` the user's name, a `cstr?`; `OS.host` the host's name, a
  `Result<String, i32>`; `OS.umask(mask)` sets the mask and gives the
  old; `OS.kill(pid, signal)` sends a signal, 0 or `errno`.
- **Time** (#95): `OS.time` is the seconds since the epoch, an `f64`
  with its fraction; `OS.sleep(seconds)` sleeps that long, a fraction
  allowed. `OS.tmpdir` is the directory for temporary files, `TMPDIR`
  or `/tmp`, a `cstr`.
- **`OS.system(command)`** runs a shell command with the program's
  streams, and gives its exit code, or -1 where it did not exit; for
  its output or input, `IO.popen` and `IO.exec` are in
  [io.md](io.md).
- **`OS.pid`** is the process id, an `i32`.
- **Paths, names and commands** are text (a literal, a `cstr`, a
  `u8^`), or a `String` or a `Bytes` in a variable; a mode, a size, a
  pid or a signal is an integer, and seconds a number.
- **In C**, each is the call of the same name, `getcwd`, `chdir`,
  `getenv`, `setenv`, `unsetenv`, `access`, `stat` and `lstat`,
  `remove`, `rename`, `mkdir`, `rmdir`, `opendir` and `readdir`,
  `symlink`, `readlink`, `link`, `unlink`, `chmod`, `truncate`,
  `realpath`, `system`, `kill`, `umask`, `getpid` and its kin,
  `getpwuid`, `gethostname`, `timespec_get` and `nanosleep`, in
  runtime/os.c, which asks for POSIX; a program needs nothing.
- **Not yet:** walking a tree, globbing, temporary files made for you,
  and setting a file's times.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `SYS` | `.argv` | the arguments, an `Array<cstr>` |
| | `.exit(code)` | ends the program |
| | `.platform` | `"macos"`, `"linux"`, ..., a `cstr` |
| `OS` | `.cwd` | the working directory, a `Result<String, i32>` |
| | `.chdir(path)` | 0 or `errno` |
| | `.env(name)` | the value, a `cstr?` |
| | `.setenv(name, value)`, `.unsetenv(name)` | 0 or `errno` |
| | `.exists(path)`, `.isdir(path)`, `.isfile(path)` | a `bool` |
| | `.remove(path)`, `.rename(from, to)`, `.mkdir(path)`, `.rmdir(path)` | 0 or `errno` |
| | `.listdir(path)` | the names, sorted, a `Result<Array<String>, i32>` |
| | `.stat(path)`, `.lstat(path)` | C's stat as a struct, a `Result<{dev, ino, mode, nlink, uid, gid, size, atime, mtime, ctime, isdir, isfile, islink}, i32>` (#95) |
| | `.islink(path)` | a `bool` |
| | `.symlink(target, path)`, `.link(from, to)`, `.unlink(path)`, `.chmod(path, mode)`, `.truncate(path, size)`, `.makedirs(path)` | 0 or `errno` |
| | `.readlink(path)`, `.realpath(path)` | a `Result<String, i32>` |
| | `.basename(path)`, `.dirname(path)`, `.join(a, b)` | a `String` |
| | `.ppid`, `.uid`, `.gid` | ids, `i32`s |
| | `.user` | the user's name, a `cstr?` |
| | `.host` | the host's name, a `Result<String, i32>` |
| | `.umask(mask)`, `.kill(pid, signal)` | the old mask; 0 or `errno` |
| | `.time`, `.sleep(seconds)` | seconds since the epoch, an `f64`; sleeps |
| | `.tmpdir` | the directory for temporary files, a `cstr` |
| | `.system(command)` | the exit code, or -1 |
| | `.pid` | the process id, an `i32` |

Neither is a value: `OS` and `SYS` are only written before `.`. The
general properties are in [properties.md](properties.md).
