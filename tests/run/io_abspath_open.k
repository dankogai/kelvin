// the name an IO opened as is the first that f.abspath keeps (#196), so a
// file removed before abspath was ever asked answers by the name it had,
// on FreeBSD too, which names no removed file; f.rename keeps the new one;
// so does OS.mkstemp's IO
#import <IO>
let main():int32 {
    var cwd = OS.cwd
    var f = IO("io_abspath_open.tmp", "w")
    if f.error == 0 {
        println(OS.remove("io_abspath_open.tmp"), " ", f.exists)   // never asked before
        var gone = f.abspath
        println(gone == OS.join(cwd.ok, "io_abspath_open.tmp"))
    }
    var g = IO("io_abspath_open2.tmp", "w")
    if g.error == 0 {
        println(g.rename("io_abspath_open3.tmp"), " ", g.path)
        println(OS.remove("io_abspath_open3.tmp"))
        var moved = g.abspath
        println(moved == OS.join(cwd.ok, "io_abspath_open3.tmp"))
    }
    var t = OS.mkstemp("io_abspath_open_")
    if t.is(ok) {
        var name = OS.basename(t.ok.path)
        println(OS.remove(t.ok.path))
        var kept = t.ok.io.abspath
        println(kept.count > 0 && OS.basename(kept) == name)
    }
    return 0
}
// out: 0 false
// out: true
// out: true io_abspath_open3.tmp
// out: 0
// out: true
// out: 0
// out: true
