// OS's listdir, walk and glob, written in Kelvin in runtime/os.k (#304),
// handing their Strings over as kOS.h has it: sorted by their bytes, a
// link to a directory not followed by walk; IO's of an open directory
// are built on them
#import <IO>
#import <errno.h> as C
let touch(path:cstr) {
    var f = IO(path, "w")
    f.close()
}
let main():int32 {
    println(OS.makedirs("os_g3/b/deep"), OS.mkdir("os_g3/A"), OS.mkdir("os_g3/empty"))
    for p in $["os_g3/a.txt", "os_g3/B.txt", "os_g3/.hidden", "os_g3/z z.k", "os_g3/b/one.txt", "os_g3/b/two.k", "os_g3/b/deep/three.txt", "os_g3/A/x.txt"] {
        touch(p)
    }
    println(OS.symlink("b", "os_g3/linkdir"))
    println(OS.listdir("os_g3").ok)
    println(OS.listdir("os_g3/empty").ok, " ", OS.listdir("os_g3.none").err == ENOENT, " ", OS.listdir("os_g3/a.txt").err == ENOTDIR)
    println(OS.walk("os_g3").ok)
    println(OS.walk("os_g3/empty").ok, " ", OS.walk("os_g3.none").err == ENOENT)
    println(OS.glob("os_g3/*/*.txt").ok, " ", OS.glob("os_g3/*.none").ok, " ", OS.glob("os_g3/[aB]*").ok)
    var d = IO("os_g3", "r")
    println(d.listdir.count, " ", d.walk.count, " ", d.glob("*.txt"))
    var all = OS.walk("os_g3").ok
    while all.count > 0 {
        let p = all.pop()
        if OS.islink(p.cstr) || OS.isfile(p.cstr) { OS.remove(p.cstr) } else { OS.rmdir(p.cstr) }
    }
    println(OS.rmdir("os_g3"))
    return 0
}
// out: 000
// out: 0
// out: [".hidden", "A", "B.txt", "a.txt", "b", "empty", "linkdir", "z z.k"]
// out: [] true true
// out: ["os_g3/.hidden", "os_g3/A", "os_g3/A/x.txt", "os_g3/B.txt", "os_g3/a.txt", "os_g3/b", "os_g3/b/deep", "os_g3/b/deep/three.txt", "os_g3/b/one.txt", "os_g3/b/two.k", "os_g3/empty", "os_g3/linkdir", "os_g3/z z.k"]
// out: [] true
// out: ["os_g3/A/x.txt", "os_g3/b/one.txt", "os_g3/linkdir/one.txt"] [] ["os_g3/B.txt", "os_g3/a.txt"]
// out: 8 13 ["os_g3/B.txt", "os_g3/a.txt"]
// out: 0
