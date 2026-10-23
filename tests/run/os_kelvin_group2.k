// OS's stat, lstat and existence checks, written in Kelvin in runtime/os.k
// (#303): a file, a directory, a link to each, a dangling link and no
// file; what differs from machine to machine is compared, not printed
#import <IO>
#import <errno.h> as C
let main():int32 {
    let old = OS.umask(0x12)                              // 022
    println(OS.mkdir("os_g2.dir"), " ", OS.symlink("os_g2.dir", "os_g2.dirlink"))
    var f = IO("os_g2.file", "w")
    f.write("hello\n")
    f.close()
    println(OS.symlink("os_g2.file", "os_g2.link"), " ", OS.symlink("os_g2.none", "os_g2.dangle"))
    let fs = OS.stat("os_g2.file").ok
    let ds = OS.stat("os_g2.dir").ok
    let ls = OS.stat("os_g2.link").ok
    let ll = OS.lstat("os_g2.link").ok
    println(fs.size, " ", fs.mode & 0x1FF, " ", fs.isfile, fs.isdir, fs.islink, " ", fs.nlink, " ", fs.uid == OS.uid, " ", fs.mtime > 0.0)
    println(ds.mode & 0x1FF, " ", ds.isfile, ds.isdir, ds.islink)
    println(ls.ino == fs.ino, " ", ls.isfile, " ", ll.ino != fs.ino, " ", ll.islink, ll.isfile, " ", ll.size)
    println(OS.stat("os_g2.dangle").err == ENOENT, " ", OS.lstat("os_g2.dangle").ok.islink, " ", OS.stat("os_g2.none").err == ENOENT, " ", OS.lstat("os_g2.none").err == ENOENT)
    for p in $["os_g2.file", "os_g2.dir", "os_g2.link", "os_g2.dirlink", "os_g2.dangle", "os_g2.none"] {
        println(p, " ", OS.exists(p), " ", OS.isdir(p), " ", OS.isfile(p), " ", OS.islink(p))
    }
    println(OS.remove("os_g2.link"), OS.remove("os_g2.dirlink"), OS.remove("os_g2.dangle"), OS.remove("os_g2.file"), OS.rmdir("os_g2.dir"), " ", OS.umask(old))
    return 0
}
// out: 0 0
// out: 0 0
// out: 6 420 truefalsefalse 1 true true
// out: 493 falsetruefalse
// out: true true true truefalse 10
// out: true true true true
// out: os_g2.file true false true false
// out: os_g2.dir true true false false
// out: os_g2.link true false true true
// out: os_g2.dirlink true true false true
// out: os_g2.dangle false false false true
// out: os_g2.none false false false false
// out: 00000 18
