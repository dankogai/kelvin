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

## `OS`: the system around it

- **`OS.cwd`** is the working directory, a `Result<String, i32>`;
  **`OS.chdir(path)`** moves to one, 0 or `errno`.
- **`OS.env(name)`** is an environment variable's value, a `cstr?`,
  `none` when it is unset.
  - **`OS.setenv(name, value)`** sets one, **`OS.unsetenv(name)`**
    removes it, each 0 or `errno`.
- **`OS.exists(path)`**, **`OS.isdir(path)`** and **`OS.isfile(path)`**
  are `bool`s: whether something is there, a directory, a regular
  file.
- **`OS.remove(path)`** removes a file or an empty directory, and
  **`OS.rename(from, to)`** renames, each 0 or `errno`.
- **`OS.mkdir(path)`** makes a directory (mode 0777, as the umask
  leaves it), and **`OS.rmdir(path)`** removes an empty one, each 0 or
  `errno`.
- **`OS.listdir(path)`** is the names in a directory, `.` and `..`
  left out, sorted by their bytes, a `Result<Array<String>, i32>`.
  - A name that is not UTF-8 ends the program, as a String made of it
    would.
- **`OS.walk(path)`** (#96) is every path under a directory, the root
  itself left out, each a `String` of the root joined with what is
  under it; a `Result<Array<String>, i32>`, the err the root's.
  - Each directory's names sorted, then what is under a directory
    among them before the next name, depth first, as `find` lists
    them.
  - A symbolic link is not followed, and a directory that cannot be
    read is passed over, as Python's `walk` passes it.
- **`OS.glob(pattern)`** is the paths a shell pattern matches, sorted,
  the same Result, with none where none match.
  - `*`, `?` and `[...]` are as the shell has them; `**` is `*`, as
    POSIX `glob` has it.
- **`OS.stat(path)`** and **`OS.lstat(path)`** (#95) are what C's
  `stat` and `lstat` give, a `Result<{dev: i64, ino: i64, mode: i32,
  nlink: i64, uid: i32, gid: i32, size: i64, atime: f64, mtime: f64,
  ctime: f64, isdir: bool, isfile: bool, islink: bool}, i32>`.
  - `lstat` of a symbolic link is the link's own, `stat` its target's.
  - The times are seconds since the epoch, `mode` C's bits, and
    `isdir`, `isfile` and `islink` read off it.
  - `OS.islink(path)` is the `bool` alone.
- **Links and the rest of a file** (#95); each `i32` is 0 or `errno`.
  - `OS.symlink(target, path)` makes a symbolic link;
    `OS.readlink(path)` reads one, a `Result<String, i32>`.
  - `OS.link(from, to)` makes a hard link; `OS.unlink(path)` removes a
    file, as `remove` does.
  - `OS.chmod(path, mode)` sets C's mode bits, an integer such as
    `0644` (C's octal).
  - `OS.truncate(path, size)` cuts or extends.
  - `OS.makedirs(path)` makes every directory on the way, as `mkdir -p`
    does.
  - `OS.realpath(path)` is the absolute path with every link followed,
    a `Result<String, i32>`.
- **Paths as text** (#95); each a new `String`.
  - `OS.basename(path)` and `OS.dirname(path)` are the last part and
    what is before it, as Python's `os.path` has them, so
    `basename("a/b/")` is `""` and `dirname("a")` is `""`,
    `dirname("/a")` `"/"`.
  - `OS.join(a, b)` joins with one `/`, and is `b` when `b` is
    absolute.
- **The process and the user** (#95).
  - `OS.ppid`, `OS.uid` and `OS.gid` are the parent's id and the
    user's and group's ids.
  - `OS.user` the user's name, a `String?`; `OS.host` the host's name,
    a `Result<String, i32>`.
  - `OS.umask(mask)` sets the mask and gives the old.
  - `OS.kill(pid, signal)` sends a signal, 0 or `errno`.
- **Temporary files** (#97): `OS.mkstemp(prefix)` makes a new file
  with a name of the prefix and six random characters, and opens it
  for reading and writing, a `Result<{io: IO, path: String}, i32>`.
  - `t.ok.io` writes and reads it, `t.ok.path` names it.
  - The block closes the IO and frees the path, the file itself
    staying until `OS.remove(t.ok.path)`.
  - `OS.mkdtemp(prefix)` makes a new directory the same way, a
    `Result<String, i32>`.
  - Both are made in `OS.tmpdir`, unless the prefix names a place with
    a `/` in it, as `"./build_"` does.
- **A file's times** (#98); each 0 or `errno`.
  - `OS.utime(path, atime, mtime)` sets when a file was last read and
    last written, in seconds since the epoch as `stat` gives them, a
    fraction allowed.
  - `OS.touch(path)` sets both to now, and makes the file, empty, when
    it is missing, as the command does.
- **A file's owner** (#99): `OS.chown(path, uid, gid)` sets who owns
  a file, `OS.lchown` a symbolic link itself.
  - -1 for an id to leave as it is.
  - Each 0 or `errno`, `EPERM` for an owner one may not give.
  - `OS.username(uid)` and `OS.groupname(gid)` are the names of the
    ids `stat` gives, each a `String?`, `none` for an id no one has.
    - A String, copied out, since C keeps the name in storage the next
      lookup overwrites.
- **Time** (#95): `OS.time` is the seconds since the epoch, an `f64`
  with its fraction; `OS.sleep(seconds)` sleeps that long, a fraction
  allowed.
  - `OS.tmpdir` is the directory for temporary files, `TMPDIR` or
    `/tmp`, without a trailing `/`, a `cstr`.
- **`OS.system(command)`** runs a shell command with the program's
  streams, and gives its exit code, or -1 where it did not exit.
  - For its output or input, `IO.popen` and `IO.exec` are in
    [io.md](io.md).
- **`OS.pid`** is the process id, an `i32`.
- **The rest of Python's `os`** (#102), what C gives plainly:
  - `OS.strerror(code)` is the message for an `errno`, a `String`, so
    no `#import` is needed to show one.
    - `var why = OS.strerror(r.err)`, then `println(why)`, since a
      String an expression gives is bound before it is printed.
    - `IO.strerror(code)` is the same, from `IO` (#103).
  - `OS.environ` is every `"NAME=value"` of the environment, a
    `Result<Array<String>, i32>`.
  - `OS.euid` and `OS.egid` the effective ids, `OS.groups` the groups
    the user is in, a `Result<Array<i32>, i32>`.
  - `OS.uname` is what `uname` gives, a Result of `{sysname, nodename,
    release, version, machine}`, each a `String`, as `uname -s`,
    `-n`, `-r`, `-v` and `-m` print them.
  - `OS.readable(path)`, `OS.writable(path)` and `OS.executable(path)`
    are C's `access`, `bool`s for this user.
  - `OS.isabs(path)` is whether it begins with `/`.
  - `OS.splitext(path)` its root and its extension, `{root: String,
    ext: String}`, the extension from the last `.` of the last part
    unless that begins it, so `.bashrc` has none.
  - `OS.normpath(path)` resolves `.`, `..` and repeated `/` by the text
    alone; `OS.relpath(path, start)` is `path` from `start`, both made
    absolute first; `OS.expanduser(path)` replaces a leading `~` or
    `~user` with the home; each a `String`.
  - `OS.samefile(a, b)` is whether two paths reach one file, by device
    and inode.
  - `OS.mkfifo(path)` makes a named pipe; `OS.sync()` asks the system
    to write everything out.
  - `OS.cpus` is how many processors are online; `OS.loadavg` the load
    over one, five and fifteen minutes, a Result of `{one: f64, five:
    f64, fifteen: f64}`.
  - `OS.urandom(n)` `n` random bytes from the system, a
    `Result<Bytes, i32>`.
  - `OS.isatty(fd)` is whether a descriptor is a terminal;
    `OS.terminalsize` the terminal on stdout as `{columns: i64, lines:
    i64}`, `ENOTTY` when stdout is no terminal.
  - `OS.diskusage(path)` the file system holding a path as `{total:
    i64, used: i64, free: i64}` in bytes, `free` what this user may
    use.
  - `OS.sep`, `OS.linesep`, `OS.devnull` and `OS.name` are `"/"`,
    `"\n"`, `"/dev/null"` and `"posix"`, `cstr`s, as Python has them.
- **From an IO** (#101): an IO opened by path does this work on its
  own path; see [io.md](io.md).
  - `f.stat` (a `Stat` straight, since the open file always answers,
    #104), `f.listdir`, `f.chmod(mode)` and the rest.
- **Paths, names and commands** are text (a literal, a `cstr`, a
  `u8^`), or a `String` or a `Bytes` in a variable.
  - A mode, a size, a pid or a signal is an integer, and seconds a
    number.
- **In C**, each is the call of the same name, in runtime/os.c, which
  asks for POSIX; a program needs nothing.
  - `getcwd`, `chdir`, `getenv`, `setenv`, `unsetenv`, `access`,
    `stat` and `lstat`, `remove`, `rename`, `mkdir`, `rmdir`,
    `opendir` and `readdir`, `symlink`, `readlink`, `link`, `unlink`,
    `chmod`, `truncate`, `realpath`, `glob`, `mkstemp`, `mkdtemp`,
    `utimensat`, `chown`, `lchown`, `getpwuid`, `getgrgid`, `system`,
    `kill`, `umask`, `getpid` and its kin, `getpwuid`, `gethostname`,
    `timespec_get` and `nanosleep`.
- **Not yet:** what C gives only with root or a scheduler, such as
  `setuid`, `chroot` and `nice`, and file descriptors handled by
  number, which an `IO` covers.

## What each member takes and gives

Each line is a member as it would be declared, in Kelvin's spelling.
`text` stands for what every path, name, pattern or command takes: a
string literal, a `cstr`, a `u8^`, or a `String` or a `Bytes` held in
a variable, read through its text.

An `i32` result that is "0 or `errno`" is 0 when the call succeeded
and otherwise the `errno` C left, which `strerror` reads. A
`Result<T, i32>` holds the `T`, or that `errno` as its `err`, so `try`
passes it up and `if let ok(v)` reads it. `Stat` below stands for the
struct of the next section.

```kelvin
SYS.argv: Array<cstr>                    // the program and its arguments; an owner, bind it
SYS.exit(code: i32)                      // ends the program; no value
SYS.platform: cstr                       // "macos", "linux", "freebsd", "openbsd", "netbsd", "windows", "unknown"

OS.cwd: Result<String, i32>              // the working directory
OS.chdir(path: text): i32                // 0 or errno
OS.env(name: text): cstr?                // the variable's value, or none; a borrow of C's, copy it to keep it
OS.setenv(name: text, value: text): i32  // 0 or errno
OS.unsetenv(name: text): i32
OS.exists(path: text): bool              // anything is there
OS.isdir(path: text): bool               // a directory, a link to one too
OS.isfile(path: text): bool              // a regular file, a link to one too
OS.islink(path: text): bool              // a symbolic link itself
OS.stat(path: text): Result<Stat, i32>   // of what the path reaches, links followed
OS.lstat(path: text): Result<Stat, i32>  // of the path itself, a link's own
OS.remove(path: text): i32               // a file, or an empty directory
OS.unlink(path: text): i32               // a file
OS.rename(from: text, to: text): i32     // replaces `to` if it is a file
OS.mkdir(path: text): i32                // one directory, mode 0777 as the umask leaves it
OS.makedirs(path: text): i32             // every directory on the way, those there already left alone
OS.rmdir(path: text): i32                // an empty directory
OS.listdir(path: text): Result<Array<String>, i32>   // the names, . and .. left out, sorted by bytes
OS.walk(path: text): Result<Array<String>, i32>      // every path under it, depth first, links not followed
OS.glob(pattern: text): Result<Array<String>, i32>   // the matches, sorted; none is an empty Array
OS.symlink(target: text, path: text): i32            // makes `path` a link to `target`
OS.readlink(path: text): Result<String, i32>         // what a link points at, as written
OS.link(from: text, to: text): i32                   // a hard link
OS.chmod(path: text, mode: i32): i32                 // C's permission bits, as 0644
OS.chown(path: text, uid: i32, gid: i32): i32        // -1 leaves an id as it is
OS.lchown(path: text, uid: i32, gid: i32): i32       // of a link itself
OS.truncate(path: text, size: i64): i32              // cuts, or extends with zeros
OS.utime(path: text, atime: f64, mtime: f64): i32    // seconds since the epoch, a fraction allowed
OS.touch(path: text): i32                            // both times now; makes the file, empty, if missing
OS.realpath(path: text): Result<String, i32>         // absolute, every link followed, no . or ..
OS.basename(path: text): String          // after the last /: basename("a/b/") is ""
OS.dirname(path: text): String           // before it: dirname("a") is "", dirname("/a") is "/"
OS.join(a: text, b: text): String        // a/b, with one /; b alone when b is absolute
OS.mkstemp(prefix: text): Result<{io: IO, path: String}, i32>   // a new file, open for "w+"
OS.mkdtemp(prefix: text): Result<String, i32>                   // a new directory
OS.tmpdir: cstr                          // TMPDIR, or /tmp, without a trailing /
OS.system(command: text): i32            // the shell command's exit code, -1 where it did not exit
OS.kill(pid: i32, signal: i32): i32      // 0 or errno
OS.umask(mask: i32): i32                 // sets the mask, gives the old one
OS.pid: i32                              // this process
OS.ppid: i32                             // its parent
OS.uid: i32                              // the user running it
OS.gid: i32                              // the user's group
OS.user: String?                         // the user's name, none when the system has none
OS.username(uid: i32): String?           // the name of an id, none for an id no one has
OS.groupname(gid: i32): String?
OS.host: Result<String, i32>             // the host's name
OS.time: f64                             // seconds since the epoch, with a fraction
OS.sleep(seconds: f64)                   // no value

OS.strerror(code: i32): String           // the message for an errno
OS.environ: Result<Array<String>, i32>   // every "NAME=value"
OS.euid: i32                             // the effective user id
OS.egid: i32                             // the effective group id
OS.groups: Result<Array<i32>, i32>       // the groups the user is in
OS.uname: Result<Uname, i32>             // {sysname, nodename, release, version, machine}, Strings
OS.readable(path: text): bool            // access for this user
OS.writable(path: text): bool
OS.executable(path: text): bool
OS.isabs(path: text): bool               // begins with /
OS.splitext(path: text): Result<{root: String, ext: String}, i32>   // never fails: a Result for the struct
OS.normpath(path: text): String          // ., .. and // resolved by the text alone
OS.relpath(path: text, start: text): String   // path from start
OS.expanduser(path: text): String        // ~ and ~user replaced
OS.samefile(a: text, b: text): bool      // one file by device and inode
OS.mkfifo(path: text): i32               // a named pipe, mode 0666 as the umask leaves it
OS.sync()                                // no value
OS.cpus: i32                             // processors online
OS.loadavg: Result<{one: f64, five: f64, fifteen: f64}, i32>
OS.urandom(n: i64): Result<Bytes, i32>   // n random bytes
OS.isatty(fd: i32): bool
OS.terminalsize: Result<{columns: i64, lines: i64}, i32>   // of stdout; ENOTTY otherwise
OS.diskusage(path: text): Result<{total: i64, used: i64, free: i64}, i32>   // bytes
OS.sep: cstr                             // "/"
OS.linesep: cstr                         // "\n"
OS.devnull: cstr                         // "/dev/null"
OS.name: cstr                            // "posix"
```

A `String` given back is a new one, an owner: bind it, and its block
frees it. A `cstr` given back, `SYS.platform`, `OS.tmpdir` and
`OS.env`'s value, is a borrow of text C keeps, which a later call of
the same kind may replace, so copy it with `String(...)` to keep it.

## The `Stat` struct

`OS.stat`, `OS.lstat`, and an IO's `stat` and `lstat`, give C's
`struct stat` as a Kelvin struct, Kelvinized. Its spelling is the
struct itself, since it has no name:

```kelvin
{dev: i64, ino: i64, mode: i32, nlink: i64, uid: i32, gid: i32, size: i64,
 atime: f64, mtime: f64, ctime: f64, isdir: bool, isfile: bool, islink: bool}
```

| Member | Type | What it is |
|---|---|---|
| `dev` | `i64` | the id of the device the file is on, C's `st_dev` |
| `ino` | `i64` | the file's inode number on it, C's `st_ino`; `dev` and `ino` together name the file, however many paths reach it |
| `mode` | `i32` | C's `st_mode`: the kind of file in its high bits and the permissions in its low ones, so `mode & 0777` is the permissions, as `chmod` sets them, and the kind is read off it by the three `bool`s below |
| `nlink` | `i64` | how many hard links the file has, C's `st_nlink` |
| `uid` | `i32` | the owner's user id; `OS.username(uid)` names it |
| `gid` | `i32` | the owner's group id; `OS.groupname(gid)` names it |
| `size` | `i64` | the size in bytes; of a directory, what the system reports |
| `atime` | `f64` | when the file was last read, in seconds since the epoch, whole seconds |
| `mtime` | `f64` | when its contents were last written; what `OS.utime` sets |
| `ctime` | `f64` | when its inode last changed: its contents, owner, mode or links; not settable |
| `isdir` | `bool` | the file is a directory |
| `isfile` | `bool` | it is a regular file |
| `islink` | `bool` | it is a symbolic link itself, which only `lstat` can say, since `stat` follows the link |

A `Stat` holds no owner, so it copies freely, prints as a struct does,
`println(st.cstr)`, and may be kept. The times are whole seconds,
what C's `st_mtime` holds everywhere; `OS.time` has a fraction.

## The other structs

Each is spelled as itself, an untagged struct, and comes in a
`Result<..., i32>`:

| From | Struct | Members |
|---|---|---|
| `OS.uname` | `{sysname: String, nodename: String, release: String, version: String, machine: String}` | the system's name (`Darwin`, `Linux`), the host's, the kernel's release and version, the machine's architecture (`arm64`, `x86_64`); each a `String` the struct owns |
| `OS.splitext(path)` | `{root: String, ext: String}` | the path up to its extension, and the extension with its `.`; `ext` is `""` where there is none |
| `OS.loadavg` | `{one: f64, five: f64, fifteen: f64}` | the load average over the last one, five and fifteen minutes |
| `OS.terminalsize` | `{columns: i64, lines: i64}` | the terminal's width and height in characters |
| `OS.diskusage(path)` | `{total: i64, used: i64, free: i64}` | the file system's size, what is used, and what this user may still use, in bytes; `used + free` may be less than `total`, the rest being reserved |

The structs of Strings own them, so bind the Result and read through
it; the structs of numbers copy freely.

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
| | `.walk(path)` | every path under a directory, depth first, a `Result<Array<String>, i32>` (#96) |
| | `.glob(pattern)` | the paths a shell pattern matches, sorted, the same |
| | `.stat(path)`, `.lstat(path)` | C's stat as a struct, a `Result<{dev, ino, mode, nlink, uid, gid, size, atime, mtime, ctime, isdir, isfile, islink}, i32>` (#95) |
| | `.islink(path)` | a `bool` |
| | `.symlink(target, path)`, `.link(from, to)`, `.unlink(path)`, `.chmod(path, mode)`, `.truncate(path, size)`, `.makedirs(path)` | 0 or `errno` |
| | `.readlink(path)`, `.realpath(path)` | a `Result<String, i32>` |
| | `.basename(path)`, `.dirname(path)`, `.join(a, b)` | a `String` |
| | `.ppid`, `.uid`, `.gid` | ids, `i32`s |
| | `.user` | the user's name, a `String?` |
| | `.host` | the host's name, a `Result<String, i32>` |
| | `.umask(mask)`, `.kill(pid, signal)` | the old mask; 0 or `errno` |
| | `.time`, `.sleep(seconds)` | seconds since the epoch, an `f64`; sleeps |
| | `.tmpdir` | the directory for temporary files, a `cstr` |
| | `.mkstemp(prefix)` | a temporary file, made and opened, a `Result<{io: IO, path: String}, i32>` (#97) |
| | `.mkdtemp(prefix)` | a temporary directory, its path, a `Result<String, i32>` |
| | `.utime(path, atime, mtime)`, `.touch(path)` | sets a file's times; both to now, making the file (#98) |
| | `.chown(path, uid, gid)`, `.lchown(path, uid, gid)` | sets a file's owner, a link's own; 0 or `errno` (#99) |
| | `.username(uid)`, `.groupname(gid)` | the names of ids, each a `String?` |
| | `.system(command)` | the exit code, or -1 |
| | `.pid` | the process id, an `i32` |

Neither is a value: `OS` and `SYS` are only written before `.`. The
general properties are in [properties.md](properties.md).
