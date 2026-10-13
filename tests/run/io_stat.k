// an open file's attributes straight (#104): f.stat is a Stat, no Result,
// since an open descriptor always answers; f.lstat is the path's own, the
// open file's where the path is gone; f.abspath a String, the descriptor's
// where the path is gone (#105), "" with neither;
// f.isdir and f.isfile from the descriptor. OS.stat(path) stays a Result:
// a path is checked anew at each call
let main():i32 {
    var f = IO("io_stat.tmp", "w")
    if f.error == 0 {
        f.write("hello")
        f.flush()
        let s = f.stat                          // a Stat, bound without a case
        println(s.size, " ", s.isfile, " ", s.isdir, " ", s.size.typename, " ", s.mode.typename)
        println(f.stat.size, " ", f.stat.nlink, " ", f.isfile, " ", f.isdir)   // the field, not sizeof
        println(f.lstat.size, " ", f.lstat.islink)
        var abs = f.abspath
        var cwd = OS.cwd
        var same = OS.join(cwd.ok, "io_stat.tmp")
        println(abs == same, " ", abs.typename)
        println(OS.remove("io_stat.tmp"), " ", f.exists, " ", f.stat.size, " ", f.lstat.size)   // gone, yet open: stat sees the file
        var gone = f.abspath                    // the descriptor still names it (#105)
        println(gone == abs, " ", f.isfile)
    }
    var out = IO.stdout
    var ends = IO.pipe()
    var none = ends.ok.reader.abspath           // a pipe has no path
    println(none.count, " ", out.stat.nlink.typename)
    var st = OS.stat("io_stat.tmp")             // of a path: a Result still
    println(st.is(err), " ", st.typename)
    return 0
}
// out: 5 true false i64 i32
// out: 5 1 true false
// out: 5 false
// out: true String
// out: 0 false 5 5
// out: true true
// out: 0 i64
// out: true Result<{dev: i64, ino: i64, mode: i32, nlink: i64, uid: i32, gid: i32, size: i64, atime: f64, mtime: f64, ctime: f64, isdir: bool, isfile: bool, islink: bool}, i32>
// c: kv_stat _kv_st = kv_io_stat((kv_io *)&f)
// c: kv_io_abspath((kv_io *)&f)
