// what Python's os has beyond the rest (#102): strerror, environ, the
// effective ids and groups, uname, readable/writable/executable, isabs,
// splitext, normpath, relpath, expanduser, samefile, mkfifo, sync, cpus,
// loadavg, urandom, isatty, the constants, terminalsize, diskusage
#import <errno.h> as C
#import <string.h> as C
#import <OS>
let main():i32 {
    var msg = OS.strerror(ENOENT)
    println(msg, " ", msg.typename)
    println(OS.setenv("KELVIN_BEYOND", "1"))
    var env = OS.environ
    var want = $"KELVIN_BEYOND=1"
    var found = false
    if let ok(es) = env { for e in es { if e == want { found = true } } }
    println(found, " ", env.typename)
    var gs = OS.groups
    var inGroups = false
    if let ok(ids) = gs { for g in ids { if g == OS.gid { inGroups = true } } }
    println(OS.euid == OS.uid, " ", OS.egid == OS.gid, " ", inGroups, " ", gs.typename)
    var u = OS.uname
    if let ok(un) = u {
        println(un.sysname.count > 0, " ", un.nodename.count > 0, " ", un.release.count > 0, " ", un.machine.count > 0,
                " ", strcmp(un.sysname.cstr, "Darwin") == 0 || strcmp(un.sysname.cstr, "Linux") == 0)
    }
    println(u.typename)
    println(OS.readable("."), " ", OS.writable("."), " ", OS.executable("/bin/sh"), " ", OS.executable("os_beyond.k.none"))
    println(OS.isabs("/a"), " ", OS.isabs("a"), " ", OS.isabs(""))
    var s1 = OS.splitext("a/b.tar.gz")
    var s2 = OS.splitext("a/.bashrc")
    var s3 = OS.splitext("a.b/c")
    var s4 = OS.splitext("a/b.")
    println(s1.ok.root, " [", s1.ok.ext, "] ", s2.ok.root, " [", s2.ok.ext, "] ", s3.ok.root, " [", s3.ok.ext, "] ",
            s4.ok.root, " [", s4.ok.ext, "]")
    println(s1.typename)
    var n1 = OS.normpath("a//b/./c/../d")
    var n2 = OS.normpath("/../a/./")
    var n3 = OS.normpath("")
    var n4 = OS.normpath("../../x")
    var n5 = OS.normpath("a/..")
    println(n1, " ", n2, " ", n3, " ", n4, " ", n5)
    var r1 = OS.relpath("/a/b/c", "/a/d")
    var r2 = OS.relpath("/a/b", "/a/b")
    var r3 = OS.relpath("/a/b/c", "/")
    var r4 = OS.relpath("/x", "/a/b")
    println(r1, " ", r2, " ", r3, " ", r4)
    var h = OS.expanduser("~")
    var h2 = OS.expanduser("~/x")
    var h3 = OS.expanduser("plain")
    var home = OS.env("HOME")
    var homeText = String(home.some)
    println(h == homeText, " ", h2.count == h.count + 2, " ", h3)
    println(OS.samefile(".", "./"), " ", OS.samefile(".", ".."))
    let fifo := "os_beyond.fifo"
    println(OS.mkfifo(fifo), " ", OS.exists(fifo), " ", OS.isfile(fifo), " ", OS.remove(fifo), " ", OS.mkfifo("/no/such/x") == ENOENT)
    OS.sync()
    var la = OS.loadavg
    println(OS.cpus >= 1, " ", la.is(ok) && la.ok.one >= 0.0 && la.ok.fifteen >= 0.0, " ", la.typename)
    var rnd = OS.urandom(16)
    var none = OS.urandom(0)
    var bad = OS.urandom(-1)
    println(rnd.ok.count, " ", none.ok.count, " ", bad.is(err), " ", rnd.typename)
    println(OS.isatty(1), " ", OS.isatty(99), " ", OS.sep, " ", OS.devnull, " ", OS.name, " ", OS.linesep.count)
    var ts = OS.terminalsize
    println(ts.is(err), " ", ts.typename)
    var du = OS.diskusage(".")
    if let ok(d) = du { println(d.total > 0, " ", d.used >= 0, " ", d.free >= 0, " ", d.used + d.free <= d.total) }
    println(du.typename, " ", OS.diskusage("/no/such").is(err))
    return 0
}
// out: No such file or directory String
// out: 0
// out: true Result<Array<String>, i32>
// out: true true true Result<Array<i32>, i32>
// out: true true true true true
// out: Result<{sysname: String, nodename: String, release: String, version: String, machine: String}, i32>
// out: true true true false
// out: true false false
// out: a/b.tar [.gz] a/.bashrc [] a.b/c [] a/b [.]
// out: Result<{root: String, ext: String}, i32>
// out: a/b/d /a . ../../x .
// out: ../b/c . a/b/c ../../x
// out: true true plain
// out: true false
// out: 0 true false 0 true
// out: true true Result<{one: f64, five: f64, fifteen: f64}, i32>
// out: 16 0 true Result<Bytes, i32>
// out: false false / /dev/null posix 1
// out: true Result<{columns: i64, lines: i64}, i32>
// out: true true true true
// out: Result<{total: i64, used: i64, free: i64}, i32> true
// c: kv_uname _kv_st = {0}; int _kv_e = kv_os_uname(&_kv_st);
// c: kv_os_groups(&_kv_at, &_kv_n)
