// OS.utime(path, atime, mtime) (#98): a file's times, in seconds since
// the epoch as stat gives them, 0 or errno; OS.touch(path): both now,
// and the file made if it is missing
#import <errno.h> as C
let main():i32 {
    let path := "os_utime.tmp"
    println(OS.exists(path), " ", OS.touch(path), " ", OS.isfile(path))
    var s0 = OS.stat(path)
    println(s0.ok.size, " ", s0.ok.mtime > 1.0e9, " ", OS.time - s0.ok.mtime < 60.0)
    println(OS.utime(path, 1000000000.0, 2000000000.5))
    var s1 = OS.stat(path)
    println(s1.ok.atime, " ", s1.ok.mtime)
    println(OS.touch(path))
    var s2 = OS.stat(path)
    println(s2.ok.mtime < 2000000000.0, " ", OS.time - s2.ok.mtime < 60.0)   // back from 2033 to now
    println(OS.utime("os_utime.none", 1.0, 1.0) == ENOENT, " ", OS.touch("/no/such/dir/x") == ENOENT)
    println(OS.remove(path))
    return 0
}
// out: false 0 true
// out: 0 true true
// out: 0
// out: 1000000000.0 2000000000.0
// out: 0
// out: true true
// out: true true
// out: 0
// c: kv_os_utime(path, 1000000000.0, 2000000000.5)
// c: kv_os_touch(path)
