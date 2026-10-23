// runtime/os.k - OS (#94, #145), written in Kelvin (#301): kelvinc
// --runtime builds it into libkOS, beside runtime/os.c, whose C it takes
// over a group at a time, each kv_ function by the name kOS.h declares.
// Each call is C's, libc's, with errno given back where C sets it and a
// default where it does not, as os.c's err_or. The helpers are static.
#import <kOS.h> as C
#import <kIO.h> as C
#import <errno.h> as C
#import <stdio.h> as C
#import <stdlib.h> as C
#import <unistd.h> as C
#import <sys/stat.h> as C
#import <signal.h> as C
#import <string.h> as C
#import <dirent.h> as C
#import <glob.h> as C
#import <pwd.h> as C
#import <grp.h> as C
#import <time.h> as C
#import <fcntl.h> as C
#import <sys/wait.h> as C

// errno where C set one, else otherwise
static let err_or(otherwise:int32):int32 {
    if errno != 0 { return errno as int32 }
    return otherwise
}

// 0 where C's call gave 0, else its errno, or otherwise
static let done(rc:int32, otherwise:int32):int32 {
    if rc == 0 { return 0 }
    return err_or(otherwise)
}

// ---------- the working directory and the environment ----------

// OS.cwd: the working directory into out, 0, or errno; the buffer
// doubled while C says it is too short
let kv_os_cwd(out:String^):int32 {
    var cap:size_t = 256
    var e:int32 = ERANGE
    while e == ERANGE {
        var buf = Bytes(cap)
        if getcwd(buf.at, cap) != nullptr {
            out^ = String(buf.at as cstr)
            return 0
        }
        e = err_or(EIO)
        cap *= 2
    }
    return e
}

let kv_os_chdir(path:const any^):int32 { done(chdir(path), EIO) }
let kv_os_env(name:const any^):cstr { getenv(name) }
let kv_os_setenv(name:const any^, value:const any^):int32 { done(setenv(name, value, 1), EINVAL) }
let kv_os_unsetenv(name:const any^):int32 { done(unsetenv(name), EINVAL) }

// ---------- files by their paths ----------

let kv_os_remove(path:const any^):int32 { done(remove(path), EIO) }
let kv_os_rename(from:const any^, to:const any^):int32 { done(rename(from, to), EIO) }
let kv_os_mkdir(path:const any^):int32 { done(mkdir(path, 0x1FF), EIO) }       // 0777
let kv_os_rmdir(path:const any^):int32 { done(rmdir(path), EIO) }
let kv_os_unlink(path:const any^):int32 { done(unlink(path), EIO) }
let kv_os_link(from:const any^, to:const any^):int32 { done(link(from, to), EIO) }
let kv_os_symlink(target:const any^, path:const any^):int32 { done(symlink(target, path), EIO) }

// ---------- the process ----------

let kv_os_pid():int32 { getpid() as int32 }
let kv_os_ppid():int32 { getppid() as int32 }
let kv_os_uid():int32 { getuid() as int32 }
let kv_os_gid():int32 { getgid() as int32 }
let kv_os_euid():int32 { geteuid() as int32 }
let kv_os_egid():int32 { getegid() as int32 }
let kv_os_umask(mask:int32):int32 { umask(mask) as int32 }
let kv_os_kill(pid:int32, sig:int32):int32 { done(kill(pid, sig), EIO) }

// ---------- stat and the existence checks (#303) ----------

// st's fields into out, as kOS.h's kv_stat has them
static let fill_stat(st:const struct stat^, out:kv_stat^) {
    out^.dev = st^.st_dev as int64
    out^.ino = st^.st_ino as int64
    out^.mode = st^.st_mode as int32
    out^.nlink = st^.st_nlink as int64
    out^.uid = st^.st_uid as int32
    out^.gid = st^.st_gid as int32
    out^.size = st^.st_size as int64
    out^.atime = st^.st_atime as float64
    out^.mtime = st^.st_mtime as float64
    out^.ctime = st^.st_ctime as float64
    out^.isdir = S_ISDIR(st^.st_mode) != 0
    out^.isfile = S_ISREG(st^.st_mode) != 0
    out^.islink = S_ISLNK(st^.st_mode) != 0
}

// OS.stat(path): the file's, following a link, into out; 0, or errno
let kv_os_stat(path:const any^, out:kv_stat^):int32 {
    var st:struct stat
    if stat(path, &st) != 0 { return err_or(EIO) }
    fill_stat(&st, out)
    return 0
}

// OS.lstat(path): the link's own, where path is one
let kv_os_lstat(path:const any^, out:kv_stat^):int32 {
    var st:struct stat
    if lstat(path, &st) != 0 { return err_or(EIO) }
    fill_stat(&st, out)
    return 0
}

let kv_os_exists(path:const any^):bool { access(path, F_OK) == 0 }

// whether path is there, following a link, and of the kind mask
static let is_mode(path:const any^, mask:uint32):bool {
    var st:struct stat
    return stat(path, &st) == 0 && ((st.st_mode as uint32) & (S_IFMT as uint32)) == mask
}

let kv_os_isdir(path:const any^):bool { is_mode(path, S_IFDIR as uint32) }
let kv_os_isfile(path:const any^):bool { is_mode(path, S_IFREG as uint32) }

let kv_os_islink(path:const any^):bool {
    var st:struct stat
    return lstat(path, &st) == 0 && S_ISLNK(st.st_mode) != 0
}

// ---------- paths (#306) ----------

// a String of the n bytes of p from from on: a path cut at a / or a .,
// which split no codepoint
static let text_of(p:cstr, from:size_t, n:size_t):String {
    let b = Bytes(&p[from], n)
    return String(&b)
}

// the index of the last c in the n bytes of p, or -1
static let last_of(p:cstr, n:size_t, c:u8):int64 {
    var i:int64 = n as int64 - 1
    while i >= 0 {
        if p[i] == c { return i }
        i -= 1
    }
    return -1
}

// OS.readlink(path): what a symbolic link holds into out; 0, or errno
let kv_os_readlink(path:const any^, out:String^):int32 {
    var buf = Bytes(4096)
    let n:int64 = readlink(path, buf.at, 4095) as int64
    if n < 0 { return err_or(EIO) }
    out^ = text_of(buf.at as cstr, 0, n as size_t)
    return 0
}

// the last part of a path after its last /, and what is before it, as
// Python's os.path has them: basename("a/b/") is "", dirname("a") is ""
let kv_os_basename(path:const any^):String {
    let p:cstr := path as cstr
    let n:size_t = strlen(p)
    let k = last_of(p, n, '/')
    if k < 0 { return String(p) }
    return text_of(p, (k + 1) as size_t, n - (k + 1) as size_t)
}

let kv_os_dirname(path:const any^):String {
    let p:cstr := path as cstr
    let k = last_of(p, strlen(p), '/')
    if k < 0 { return $"" }
    var m:int64 = k
    while m > 1 && p[m - 1] == '/' { m -= 1 }
    if m == 0 { m = 1 }                          // "/a": the root
    return text_of(p, 0, m as size_t)
}

// OS.join(a, b): b where it is absolute or a is empty, else a / b
let kv_os_join(a:const any^, b:const any^):String {
    let x:cstr := a as cstr
    let y:cstr := b as cstr
    if y[0] == '/' || x[0] == 0 { return String(y) }
    var s = String(x)
    if x[strlen(x) - 1] != '/' { s += "/" }
    s += y
    return s
}

// OS.realpath(path): the absolute path, links resolved, into out
let kv_os_realpath(path:const any^, out:String^):int32 {
    let r:cstr := realpath(path, nullptr)
    if r == nullptr { return err_or(EIO) }
    out^ = String(r)
    free(r as any^)
    return 0
}

let kv_os_isabs(path:const any^):bool { (path as cstr)[0] == '/' }

// OS.splitext(path): the root and the extension, as Python's splitext
// has them: the last . of the last part, unless it begins the part, the
// first of a run of dots, and none of a part all dots
let kv_os_splitext(path:const any^, out:kv_splitext^):int32 {
    let p:cstr := path as cstr
    let n:size_t = strlen(p)
    let base:int64 = last_of(p, n, '/') + 1
    var dot:int64 = n as int64 - 1
    while dot >= base && p[dot] != '.' { dot -= 1 }
    while dot > base && p[dot - 1] == '.' { dot -= 1 }
    var q:int64 = base
    while q < n as int64 && p[q] == '.' { q += 1 }
    if dot < base || dot == base || q == n as int64 {
        out^.root = String(p)
        out^.ext = $""
        return 0
    }
    out^.root = text_of(p, 0, dot as size_t)
    out^.ext = text_of(p, dot as size_t, n - dot as size_t)
    return 0
}

// OS.normpath(path): . and .. and repeated / resolved by the text alone,
// as Python's normpath does: "a//b/./c/../d" is "a/b/d", "" is "."
let kv_os_normpath(path:const any^):String {
    let p:cstr := path as cstr
    let n:size_t = strlen(p)
    if n == 0 { return $"." }
    let absolute = p[0] == '/'
    var parts:$[String] = $[]
    var i:size_t = 0
    while i < n {
        while i < n && p[i] == '/' { i += 1 }
        let from = i
        while i < n && p[i] != '/' { i += 1 }
        if i == from { break }
        let part = text_of(p, from, i - from)
        if part == $"." { continue }
        if part == $".." {
            if parts.count > 0 && parts[parts.count - 1] != $".." {
                parts.pop()
                continue
            }
            if absolute { continue }
        }
        parts += &part
    }
    var s = $""
    if absolute { s += "/" }
    for k in 0..<parts.count {
        if k > 0 { s += "/" }
        s += &parts[k]
    }
    if !absolute && parts.count == 0 { s += "." }
    return s
}

// OS.relpath(path, start): path from start, both made absolute by the
// text: "../b/c" from /a/d to /a/b/c
let kv_os_relpath(path:const any^, start:const any^):String {
    var cwd = $""
    if kv_os_cwd(&cwd) != 0 { cwd = $"/" }
    let ap:String = kv_os_isabs(path) ? kv_os_normpath(path) : kv_os_join(cwd.cstr, path)
    let sp:String = kv_os_isabs(start) ? kv_os_normpath(start) : kv_os_join(cwd.cstr, start)
    let np = kv_os_normpath(ap.cstr)
    let ns = kv_os_normpath(sp.cstr)
    let a:cstr := np.cstr
    let b:cstr := ns.cstr
    var i:size_t = 0                             // the common parts
    while a[i] != 0 && b[i] != 0 && a[i] == b[i] { i += 1 }
    while i > 0 && !((a[i] == '/' || a[i] == 0) && (b[i] == '/' || b[i] == 0)) { i -= 1 }
    if i == 0 || (a[i] != '/' && a[i] != 0) || (b[i] != '/' && b[i] != 0) {
        while i > 0 && a[i] != '/' { i -= 1 }
    }
    var r = $""
    var q:size_t = i
    while b[q] != 0 {
        if b[q] == '/' && b[q + 1] != 0 {
            if r.count > 0 { r += "/" }
            r += ".."
        }
        q += 1
    }
    if b[i] != 0 && b[i] != '/' && i == 0 { r = $"" }   // nothing in common but the root
    var rest:size_t = i
    while a[rest] == '/' { rest += 1 }
    if a[rest] != 0 {
        if r.count > 0 { r += "/" }
        r += text_of(a, rest, strlen(a) - rest)
    }
    if r.count == 0 { r += "." }
    return r
}

// OS.expanduser(path): ~ and ~user, as the shell has them; the rest as
// written
let kv_os_expanduser(path:const any^):String {
    let p:cstr := path as cstr
    if p[0] != '~' { return String(p) }
    let n:size_t = strlen(p)
    var slash:int64 = -1
    var k:int64 = 0
    while k < n as int64 && slash < 0 {
        if p[k] == '/' { slash = k }
        k += 1
    }
    var namelen:int64 = n as int64 - 1
    if slash >= 0 { namelen = slash - 1 }
    var home:cstr := nullptr
    if namelen == 0 {
        home := getenv("HOME")
        if home == nullptr || home[0] == 0 {
            let pw:struct passwd^ := getpwuid(getuid())
            home := nullptr
            if pw != nullptr { home := pw^.pw_dir as cstr }
        }
    } else {
        if namelen >= 256 { return String(p) }
        let name = text_of(p, 1, namelen as size_t)
        let pw:struct passwd^ := getpwnam(name.cstr)
        if pw != nullptr { home := pw^.pw_dir as cstr }
    }
    if home == nullptr { return String(p) }
    var s = String(home)
    if slash >= 0 { s += text_of(p, slash as size_t, n - slash as size_t) }
    return s
}

// ---------- directories, walk and glob (#304) ----------

// names, handed to C's caller as kOS.h has it: a buffer of Strings,
// calloc's, which the caller takes over into an Array and frees
static let hand_over(names:$[String]^, out:String^^, count:size_t^) {
    let n:size_t = names^.count
    var buf:String^ := calloc(n + 1, sizeof(kv_string)) as String^
    var i:size_t = n
    while i > 0 {
        i -= 1
        buf[i] = names^.pop()
    }
    out^ := buf
    count^ = n
}

// the names in a directory, but . and .., sorted by their bytes, into
// names; 0, or errno. A name that is not UTF-8 ends the program, as a
// String made of it does
static let names_in(path:const any^, names:$[String]^):int32 {
    let d:DIR^ := opendir(path)
    if d == nullptr { return err_or(EIO) }
    errno = 0
    var e:struct dirent^ := readdir(d)
    while e != nullptr {
        let name:cstr := e^.d_name as cstr
        if strcmp(name, ".") != 0 && strcmp(name, "..") != 0 { names^ += String(name) }
        errno = 0
        e := readdir(d)
    }
    let err:int32 = errno as int32
    closedir(d)
    if err != 0 { return err }
    names^.sort { (a:String, b:String):bool in a < b }
    return 0
}

// OS.listdir(path): the names in a directory, sorted, handed over
let kv_os_listdir(path:const any^, out:String^^, count:size_t^):int32 {
    var names:$[String] = $[]
    let e = names_in(path, &names)
    if e != 0 { return e }
    hand_over(&names, out, count)
    return 0
}

// each name in dir, sorted, then what is under a directory among them,
// depth first, into all; a directory that cannot be read is passed
// over, as Python's walk passes it, and a symbolic link is not followed
static let walk_into(dir:const any^, all:$[String]^):int32 {
    var names:$[String] = $[]
    let e = names_in(dir, &names)
    if e != 0 { return e }
    for name in names {
        var full:String = kv_os_join(dir, name.cstr)
        var st:struct stat
        let into = lstat(full.cstr, &st) == 0 && S_ISDIR(st.st_mode) != 0
        all^ += &full
        if into { walk_into(full.cstr, all) }
    }
    return 0
}

// OS.walk(path): every path under a directory, depth first, handed over
let kv_os_walk(path:const any^, out:String^^, count:size_t^):int32 {
    var all:$[String] = $[]
    let e = walk_into(path, &all)
    if e != 0 { return e }
    hand_over(&all, out, count)
    return 0
}

// OS.glob(pattern): the paths a shell pattern matches, sorted, as glob
// sorts them, none where none match
let kv_os_glob(pattern:const any^, out:String^^, count:size_t^):int32 {
    var g:glob_t
    let r:int32 = glob(pattern, 0, nullptr, &g)
    if r == GLOB_NOMATCH {
        out^ := nullptr
        count^ = 0
        return 0
    }
    if r == GLOB_NOSPACE { return ENOMEM }
    if r != 0 { return err_or(EIO) }
    var paths:$[String] = $[]
    for i in 0..<g.gl_pathc {
        let p:cstr := g.gl_pathv[i] as cstr
        paths += String(p)
    }
    globfree(&g)
    hand_over(&paths, out, count)
    return 0
}

// ---------- users and groups, and a file's owner (#305) ----------

// OS.user: the user's name into out, or false where there is none; the
// name copied out of getpwuid's storage, which the next lookup overwrites
let kv_os_user(out:String^):bool {
    let pw:struct passwd^ := getpwuid(getuid())
    if pw == nullptr { return false }
    out^ = String(pw^.pw_name as cstr)
    return true
}

// OS.username(uid), OS.groupname(gid): the names of ids, as OS.user's
let kv_os_username(uid:int32, out:String^):bool {
    let pw:struct passwd^ := getpwuid(uid)
    if pw == nullptr { return false }
    out^ = String(pw^.pw_name as cstr)
    return true
}

let kv_os_groupname(gid:int32, out:String^):bool {
    let gr:struct group^ := getgrgid(gid)
    if gr == nullptr { return false }
    out^ = String(gr^.gr_name as cstr)
    return true
}

// OS.groups: the groups the user is in, as getgroups gives them, in a
// buffer of int32s, malloc's, which the caller takes over and frees
let kv_os_groups(out:int32^^, count:size_t^):int32 {
    let n:int32 = getgroups(0, nullptr)
    if n < 0 { return err_or(EIO) }
    var room:size_t = 1
    if n > 0 { room = n as size_t }
    let gs:gid_t^ := malloc(room * sizeof(gid_t)) as gid_t^
    if gs == nullptr { return ENOMEM }
    let got:int32 = getgroups(n, gs)
    if got < 0 {
        let e = err_or(EIO)
        free(gs)
        return e
    }
    let at:int32^ := malloc(room * sizeof(int32_t)) as int32^
    if at == nullptr {
        free(gs)
        return ENOMEM
    }
    for i in 0..<got {
        at[i] = gs[i] as int32
    }
    free(gs)
    out^ := at
    count^ = got as size_t
    return 0
}

// OS.chown(path, uid, gid), OS.lchown(...): a file's owner, a link's own
let kv_os_chown(path:const any^, uid:int32, gid:int32):int32 { done(chown(path, uid, gid), EIO) }
let kv_os_lchown(path:const any^, uid:int32, gid:int32):int32 { done(lchown(path, uid, gid), EIO) }

// ---------- processes and time (#309) ----------

// OS.system(command): a shell command's exit code, or -1 where it did
// not exit; every stream flushed first
let kv_os_system(command:const any^):int32 {
    fflush(nullptr)
    let st:int32 = system(command)
    if st != -1 && WIFEXITED(st) != 0 { return WEXITSTATUS(st) as int32 }
    return -1
}

// OS.time: seconds since the epoch, to the nanosecond where C says
let kv_os_time():float64 {
    var ts:struct timespec
    if timespec_get(&ts, TIME_UTC) == 0 { return time(nullptr) as float64 }
    return (ts.tv_sec as float64) + (ts.tv_nsec as float64) / 1e9
}

// OS.sleep(seconds): sleeps, resuming where a signal breaks it off
let kv_os_sleep(seconds:float64) {
    if seconds <= 0.0 { return }
    var ts:struct timespec
    let whole:int64 = seconds as int64
    ts.tv_sec = whole
    ts.tv_nsec = ((seconds - (whole as float64)) * 1e9) as int64
    while nanosleep(&ts, &ts) != 0 && errno == EINTR {}
}

// the time s seconds after the epoch, as utimensat takes it
static let at_seconds(s:float64, ts:struct timespec^) {
    let whole:int64 = s as int64
    ts^.tv_sec = whole
    ts^.tv_nsec = ((s - (whole as float64)) * 1e9) as int64
    if ts^.tv_nsec < 0 { ts^.tv_nsec = 0 }
}

// OS.utime(path, atime, mtime): a file's times
let kv_os_utime(path:const any^, atime:float64, mtime:float64):int32 {
    var ts:[struct timespec](2)
    at_seconds(atime, &ts[0])
    at_seconds(mtime, &ts[1])
    return done(utimensat(AT_FDCWD, path, &ts[0], 0), EIO)
}

// the same of an open descriptor, for an IO (#108)
let kv_os_futime(fd:int32, atime:float64, mtime:float64):int32 {
    var ts:[struct timespec](2)
    at_seconds(atime, &ts[0])
    at_seconds(mtime, &ts[1])
    return done(futimens(fd, &ts[0]), EIO)
}

// both times now
static let now_both(ts:struct timespec^) {
    ts^.tv_sec = 0
    ts^.tv_nsec = UTIME_NOW
}

let kv_os_ftouch(fd:int32):int32 {
    var ts:[struct timespec](2)
    now_both(&ts[0])
    now_both(&ts[1])
    return done(futimens(fd, &ts[0]), EIO)
}

// OS.touch(path): both times now, and the file made if it is missing, as
// touch does
let kv_os_touch(path:const any^):int32 {
    let fd:int32 = open(path, O_WRONLY | O_CREAT, 0x1B6)          // 0666
    if fd < 0 { return err_or(EIO) }
    close(fd)
    var ts:[struct timespec](2)
    now_both(&ts[0])
    now_both(&ts[1])
    return done(utimensat(AT_FDCWD, path, &ts[0], 0), EIO)
}

// ---------- temporary files (#310) ----------

static var tmpdir_text:[u8](4096)

// OS.tmpdir: TMPDIR, or /tmp, without a trailing /, which macOS's TMPDIR
// has, in a buffer of this file's
let kv_os_tmpdir():cstr {
    var t:cstr := getenv("TMPDIR")
    if t == nullptr || t[0] == 0 { t := "/tmp" }
    var n:size_t = strlen(t)
    while n > 1 && t[n - 1] == '/' { n -= 1 }
    if n >= 4096 { n = 4095 }
    memcpy(&tmpdir_text[0], t, n)
    tmpdir_text[n] = 0
    return &tmpdir_text[0]
}

// the template mkstemp and mkdtemp want, malloc's: the prefix, in tmpdir
// unless it names a place itself, and six X
static let temp_template(prefix:const any^):u8^ {
    let p:cstr := prefix as cstr
    var dir:cstr := ""
    if strchr(p, '/') == nullptr { dir := kv_os_tmpdir() }
    var sep:cstr := ""
    if dir[0] != 0 { sep := "/" }
    let n:size_t = strlen(dir) + 1 + strlen(p) + 7
    let t:u8^ := malloc(n) as u8^
    if t == nullptr { return nullptr }
    snprintf(t, n, "%s%s%sXXXXXX", dir, sep, p)
    return t
}

// OS.mkstemp(prefix): a temporary file, made and opened for reading and
// writing, into io, which an IO is (#97), and its path
let kv_os_mkstemp(prefix:const any^, io:kv_io^, path:String^):int32 {
    let t:u8^ := temp_template(prefix)
    if t == nullptr { return ENOMEM }
    let fd:int32 = mkstemp(t)
    if fd < 0 {
        let e = err_or(EIO)
        free(t)
        return e
    }
    let fp:any^ := fdopen(fd, "w+")
    if fp == nullptr {
        let e = err_or(EIO)
        close(fd)
        unlink(t)
        free(t)
        return e
    }
    io^.fp = fp
    io^.kind = 1
    io^.status = -1
    io^.signal = -1
    io^.pid = 0
    io^.named = realpath(t, nullptr)           // the first name abspath keeps (#196)
    path^ = String(t as cstr)
    let n:size_t = strlen(t) + 1
    let copy:u8^ := malloc(n) as u8^
    if copy != nullptr { memcpy(copy, t, n) }
    io^.path = copy
    free(t)
    return 0
}

// OS.mkdtemp(prefix): a temporary directory, made, its path into out
let kv_os_mkdtemp(prefix:const any^, out:String^):int32 {
    let t:u8^ := temp_template(prefix)
    if t == nullptr { return ENOMEM }
    if mkdtemp(t) == nullptr {
        let e = err_or(EIO)
        free(t)
        return e
    }
    out^ = String(t as cstr)
    free(t)
    return 0
}
