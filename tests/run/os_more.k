// more of OS (#95): stat and lstat as a Result of a struct, links,
// modes and sizes, makedirs, the ids, the user and host, time and
// sleep, tmpdir, and the path helpers basename, dirname, join and
// realpath
#import <errno.h> as C
#import <string.h> as C
#import <IO>
let main():int32 {
    let dir := "os_more.tmpdir"
    println(OS.makedirs("os_more.tmpdir/a/b"), " ", OS.isdir("os_more.tmpdir/a/b"), " ", OS.makedirs("os_more.tmpdir/a"))
    var f = IO("os_more.tmpdir/a/b/f.txt", "w")
    f.write("12345")
    f.close()
    var st = OS.stat("os_more.tmpdir/a/b/f.txt")
    if let ok(s) = st {
        println(s.size, " ", s.isfile, " ", s.isdir, " ", s.islink, " ", s.nlink, " ", s.mtime > 1.0e9, " ", s.uid == OS.uid,
                " ", (s.mode & 511) != 0)
    }
    println(st.typename)
    println(OS.symlink("b/f.txt", "os_more.tmpdir/a/link"), " ", OS.islink("os_more.tmpdir/a/link"), " ",
            OS.isfile("os_more.tmpdir/a/link"))
    var target = OS.readlink("os_more.tmpdir/a/link")
    println(target.cstr)
    var ls = OS.lstat("os_more.tmpdir/a/link")
    var fs = OS.stat("os_more.tmpdir/a/link")
    if let ok(l) = ls { if let ok(s) = fs { println(l.islink, " ", s.islink, " ", s.size) } }
    println(OS.link("os_more.tmpdir/a/b/f.txt", "os_more.tmpdir/a/hard"), " ", OS.stat("os_more.tmpdir/a/hard").ok.nlink)
    println(OS.chmod("os_more.tmpdir/a/hard", 384), " ", OS.stat("os_more.tmpdir/a/hard").ok.mode & 511, " ",
            OS.truncate("os_more.tmpdir/a/hard", 2), " ", OS.stat("os_more.tmpdir/a/b/f.txt").ok.size)
    var missing = OS.stat("os_more.tmpdir/none")
    println(missing.is(err), " ", missing.err == ENOENT, " ", OS.lstat("os_more.tmpdir/none").is(err))
    var real = OS.realpath("os_more.tmpdir/a/../a/b")
    var base = OS.basename(real.ok)
    println(base, " ", real.ok.count > 4)
    var b1 = OS.basename("x/y/z.txt")
    var b2 = OS.basename("x/y/")
    var d1 = OS.dirname("x/y/z.txt")
    var d2 = OS.dirname("z.txt")
    var d3 = OS.dirname("/z.txt")
    var j1 = OS.join("x/y", "z")
    var j2 = OS.join("x/y/", "z")
    var j3 = OS.join("x", "/abs")
    var j4 = OS.join("", "z")
    println(b1, " [", b2, "] ", d1, " [", d2, "] ", d3)
    println(j1, " ", j2, " ", j3, " ", j4, " ", j1.typename)
    println(OS.unlink("os_more.tmpdir/a/link"), " ", OS.unlink("os_more.tmpdir/a/hard"), " ",
            OS.remove("os_more.tmpdir/a/b/f.txt"), " ", OS.rmdir("os_more.tmpdir/a/b"), " ", OS.rmdir("os_more.tmpdir/a"),
            " ", OS.rmdir(dir), " ", OS.exists(dir))
    var user = OS.user
    var host = OS.host
    println(OS.ppid > 0, " ", OS.uid >= 0, " ", OS.gid >= 0, " ", user.is(some), " ", host.is(ok))
    let old = OS.umask(18)
    println(OS.umask(old) == 18, " ", OS.kill(OS.pid, 0), " ", OS.kill(999999, 0) != 0)
    let t0 = OS.time
    OS.sleep(0.05)
    let t1 = OS.time
    println(t1 - t0 >= 0.04, " ", t1 - t0 < 5.0, " ", t0 > 1.0e9, " ", t0.typename)
    let tmp := OS.tmpdir
    println(tmp.count > 0, " ", OS.isdir(tmp), " ", tmp.typename)
    return 0
}
// out: 0 true 0
// out: 5 true false false 1 true true true
// out: Result<{dev: i64, ino: i64, mode: i32, nlink: i64, uid: i32, gid: i32, size: i64, atime: f64, mtime: f64, ctime: f64, isdir: bool, isfile: bool, islink: bool}, i32>
// out: 0 true true
// out: ok("b/f.txt")
// out: true false 5
// out: 0 2
// out: 0 384 0 2
// out: true true true
// out: b true
// out: z.txt [] x/y [] /
// out: x/y/z x/y/z /abs z String
// out: 0 0 0 0 0 0 false
// out: true true true true true
// out: true 0 true
// out: true true true f64
// out: true true cstr
// c: kv_os_lstat("os_more.tmpdir/a/link", &_kv_st)
// c: .size = _kv_st.size
