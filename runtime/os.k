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
