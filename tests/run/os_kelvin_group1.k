// OS's first group, written in Kelvin in runtime/os.k (#301): the working
// directory, the environment, files by path and the process, each 0 or
// C's errno as os.c gave them, compared with errno.h's names, which are
// the platform's
#import <IO>
#import <errno.h> as C
let main():int32 {
    let start = OS.cwd
    println(start.ok.count > 0, " ", OS.chdir("os_g1.nowhere") == ENOENT, " ", OS.mkdir("os_g1.dir"), " ", OS.mkdir("os_g1.dir") == EEXIST, " ", OS.chdir("os_g1.dir"))
    let inside = OS.cwd
    println(inside.ok.ends("/os_g1.dir"), " ", OS.chdir(".."))
    println(OS.setenv("OS_G1_X", "1"), " ", OS.env("OS_G1_X")!, " ", OS.unsetenv("OS_G1_X"), " ", OS.env("OS_G1_X") == none, " ", OS.setenv("", "x") == EINVAL, " ", OS.unsetenv("A=B") == EINVAL)
    var f = IO("os_g1.dir/a.txt", "w")
    f.write("x")
    f.close()
    println(OS.link("os_g1.dir/a.txt", "os_g1.dir/b.txt"), " ", OS.link("os_g1.dir/none", "os_g1.dir/c.txt") == ENOENT, " ", OS.symlink("a.txt", "os_g1.dir/s.txt"), " ", OS.symlink("a.txt", "os_g1.dir/s.txt") == EEXIST)
    println(OS.rename("os_g1.dir/b.txt", "os_g1.dir/d.txt"), " ", OS.rename("os_g1.dir/none", "os_g1.dir/e.txt") == ENOENT, " ", OS.unlink("os_g1.dir/d.txt"), " ", OS.unlink("os_g1.dir/d.txt") == ENOENT, " ", OS.remove("os_g1.dir/s.txt"), " ", OS.remove("os_g1.dir/s.txt") == ENOENT)
    println(OS.rmdir("os_g1.dir") != 0, " ", OS.remove("os_g1.dir/a.txt"), " ", OS.rmdir("os_g1.dir"), " ", OS.rmdir("os_g1.dir") == ENOENT)
    println(OS.pid > 0, " ", OS.ppid > 0, " ", OS.uid >= 0, " ", OS.gid >= 0, " ", OS.euid >= 0, " ", OS.egid >= 0)
    let old = OS.umask(0x12)
    println(OS.umask(old), " ", OS.kill(OS.pid, 0), " ", OS.kill(999999, 0) == ESRCH)
    return 0
}
// out: true true 0 true 0
// out: true 0
// out: 0 1 0 true true true
// out: 0 true 0 true
// out: 0 true 0 true 0 true
// out: true 0 0 true
// out: true true true true true true
// out: 18 0 true
