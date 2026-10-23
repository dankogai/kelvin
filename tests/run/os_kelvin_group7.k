// OS's temporary files, written in Kelvin in runtime/os.k (#310): tmpdir
// is TMPDIR without its trailing slashes, /tmp when TMPDIR is unset or
// empty; mkstemp makes and opens a file of the prefix and six random
// characters there, or where the prefix names a place with a /; mkdtemp
// a directory the same way; each gives errno where it cannot
#import <IO>
#import <errno.h> as C
let main():int32 {
    OS.unsetenv("TMPDIR")
    println(OS.tmpdir)
    OS.setenv("TMPDIR", "")
    println(OS.tmpdir)
    OS.setenv("TMPDIR", "/")
    println(OS.tmpdir)
    println(OS.mkdir("os_g7.d"))
    var cwd = OS.cwd.ok
    var td = OS.join(cwd, "os_g7.d")
    var slashed = td + "///"
    OS.setenv("TMPDIR", slashed)
    println(String(OS.tmpdir) == td)
    var t = OS.mkstemp("kv_g7_")
    if t.is(ok) {
        println(OS.dirname(t.ok.path) == td, " ", OS.basename(t.ok.path).count, " ", OS.isfile(t.ok.path))
        println(String(t.ok.io.path) == t.ok.path, " ", t.ok.io.abspath == t.ok.path)
        t.ok.io.print("written")
        t.ok.io.rewind()
        println(t.ok.io.string, " ", OS.remove(t.ok.path))
    }
    var d = OS.mkdtemp("kv_g7d_")
    if let ok(p) = d { println(OS.dirname(p) == td, " ", OS.basename(p).count, " ", OS.isdir(p), " ", OS.rmdir(p)) }
    var here = OS.mkstemp("./kv_g7_")
    if let ok(h) = here { println(h.path.starts("./kv_g7_"), " ", h.path.count, " ", OS.remove(h.path)) }
    println(OS.mkstemp("os_g7.none/kv_").err == ENOENT, " ", OS.mkdtemp("os_g7.none/kv_").err == ENOENT)
    println(OS.listdir("os_g7.d").ok.count, " ", OS.rmdir("os_g7.d"))
    return 0
}
// out: /tmp
// out: /tmp
// out: /
// out: 0
// out: true
// out: true 12 true
// out: true true
// out: written 0
// out: true 13 true 0
// out: true 14 0
// out: true true
// out: 0 0
