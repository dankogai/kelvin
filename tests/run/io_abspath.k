// f.abspath when the path is gone (#105): of the open descriptor, as the
// system names it, so a file renamed behind the IO's back answers by its
// new name and a removed one by the name it had; "" where neither the path
// nor the descriptor answers, as of a pipe
let main():i32 {
    var w = IO("io_abspath.tmp", "w")
    if let ok(f) = w {
        f.write("x")
        f.flush()
        var cwd = OS.cwd
        var abs = f.abspath
        var here = OS.join(cwd.ok, "io_abspath.tmp")
        println(abs == here, " ", abs.typename)
        println(OS.rename("io_abspath.tmp", "io_abspath2.tmp"), " ", f.path, " ", f.exists)   // the path is stale
        var moved = f.abspath
        var there = OS.join(cwd.ok, "io_abspath2.tmp")
        println(moved == there)                      // the descriptor's name
        println(OS.remove("io_abspath2.tmp"), " ", f.exists)
        var gone = f.abspath
        println(gone == there, " ", f.stat.size)    // by the name it had; the file is still open
    }
    var ends = IO.pipe()
    if let ok(p) = ends {
        var none = p.reader.abspath
        println(none.count, " ", none.typename)
    }
    return 0
}
// out: true String
// out: 0 io_abspath.tmp false
// out: true
// out: 0 false
// out: true 1
// out: 0 String
// c: kv_io_abspath((kv_io *)&f)
