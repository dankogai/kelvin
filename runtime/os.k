// runtime/os.k - OS (#94, #145), written in Kelvin (#301): kelvinc
// --runtime builds it into libkOS, beside runtime/os.c, whose C it takes
// over a group at a time, each kv_ function by the name kOS.h declares.
// Each call is C's, libc's, with errno given back where C sets it and a
// default where it does not, as os.c's err_or. The helpers are static.
#import <kOS.h> as C
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
