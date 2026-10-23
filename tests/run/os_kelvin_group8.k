// OS's system, written in Kelvin in runtime/os.k (#311): the host's
// name, uname's names, the processors online, the load average, the
// terminal on stdout, which a test's piped stdout is not, and a file
// system's bytes, each a Result where C can fail
#import <OS>
#import <errno.h> as C
let main():int32 {
    var h = OS.host
    if let ok(name) = h { println(name.count > 0) }
    var u = OS.uname
    if let ok(x) = u { println(x.sysname.count > 0, " ", x.release.count > 0, " ", x.machine.count > 0) }
    println(OS.cpus >= 1)
    var l = OS.loadavg
    if let ok(a) = l { println(a.one >= 0.0, " ", a.five >= 0.0, " ", a.fifteen >= 0.0) }
    var t = OS.terminalsize
    println(t.is(err), " ", t.err == ENOTTY)
    var d = OS.diskusage(".")
    if let ok(s) = d { println(s.total > 0, " ", s.used >= 0 && s.used <= s.total, " ", s.free >= 0 && s.free <= s.total) }
    println(OS.diskusage("os_g8.none").err == ENOENT)
    return 0
}
// out: true
// out: true true true
// out: true
// out: true true true
// out: true true
// out: true true true
// out: true
