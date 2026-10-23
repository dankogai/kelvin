// OS's processes and time, written in Kelvin in runtime/os.k (#309): a
// shell command's exit code, -1 where a signal ended it, the streams
// flushed before; the time, a sleep, a file's times set exactly, touch
// making a file, and an open file's, as IO's utime and touch use them
#import <IO>
#import <errno.h> as C
let main():int32 {
    print("before ")
    println(OS.system("echo inside"), " ", OS.system("exit 3"), " ", OS.system("kill -9 $$"), " ", OS.system("true"))
    let t0 = OS.time
    OS.sleep(0.05)
    OS.sleep(-1.0)
    let t1 = OS.time
    println(t0 > 1.7e9, " ", t1 - t0 >= 0.05, " ", t1 - t0 < 1.0)
    println(OS.touch("os_g6.file"), " ", OS.exists("os_g6.file"), " ", OS.utime("os_g6.file", 1000000000.5, 1234567890.25), " ", OS.stat("os_g6.file").ok.mtime, " ", OS.stat("os_g6.file").ok.atime)
    println(OS.touch("os_g6.file"), " ", OS.stat("os_g6.file").ok.mtime > 1.7e9, " ", OS.utime("os_g6.none", 1.0, 2.0) == ENOENT, " ", OS.touch("os_g6.nodir/x") == ENOENT)
    var f = IO("os_g6.file", "r")
    println(f.utime(1500000000.0, 1600000000.0), " ", OS.stat("os_g6.file").ok.mtime, " ", f.touch(), " ", OS.stat("os_g6.file").ok.mtime > 1.7e9)
    f.close()
    println(OS.remove("os_g6.file"))
    return 0
}
// out: before inside
// out: 0 3 -1 0
// out: true true true
// out: 0 true 0 1234567890.0 1000000000.0
// out: 0 true true true
// out: true 1600000000.0 true true
// out: 0
