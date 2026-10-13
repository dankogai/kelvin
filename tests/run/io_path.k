// an IO's path (#101): f.path as given, f.abspath resolved; the OS's work
// on it from the IO: listdir, walk, glob, stat (of the open file itself, a
// Stat straight, #104),
// lstat, isdir, isfile, islink, exists, chmod, chown, truncate, remove,
// rename (the path follows), utime, touch, each true when done (#108),
// basename, dirname, join; and
// IO(path) alone opens for reading, a directory too
#import <errno.h> as C
let main():i32 {
    println(OS.makedirs("io_path.tmpdir/sub"))
    var f = IO("io_path.tmpdir/sub/f.txt", "w")
    if f.error == 0 {
        f.write("hello")
        f.flush()
        var st = f.stat
        println(f.path, " ", st.size, " ", f.isfile, " ", f.isdir, " ", f.exists, " ", f.islink)
        println(f.chmod(384), " ", f.stat.mode & 511, " ", f.truncate(2), " ", f.stat.size)
        var base = f.basename
        var dir = f.dirname
        var joined = f.join("x")
        println(base, " ", dir, " ", joined, " ", base.typename)
        println(f.chown(OS.uid, -1), " ", f.utime(1000000000.0, 1000000000.0), " ", f.lstat.mtime, " ", f.touch())
    }
    var dir = IO("io_path.tmpdir")               // a directory, opened for reading
    if dir.error == 0 {
        println(dir.path, " ", dir.isdir, " ", dir.isfile)
        var names = dir.listdir                  // Arrays straight (#106)
        for n in names { print("[", n, "]") }
        println()
        var all = dir.walk
        for p in all { println(p) }
        var txt = dir.glob("*/*.txt")
        for p in txt { println(p) }
        var abs = dir.abspath
        var cwd = OS.cwd
        var rel = OS.join(cwd.ok, "io_path.tmpdir")
        println(abs == rel, " ", abs.typename)
    }
    var m = IO("io_path.tmpdir/sub/f.txt", "r+")
    if m.error == 0 {
        println(m.rename("io_path.tmpdir/sub/g.txt"), " ", m.path, " ", OS.exists("io_path.tmpdir/sub/g.txt"))
        println(m.remove(), " ", m.exists, " ", m.stat.size)   // removed, yet open: stat sees the file
        m.close()
    }
    var out = IO.stdout
    var ends = IO.pipe()                         // a pipe end has no path, by name or by descriptor (#105)
    var noPath = ends.ok.reader.abspath
    var noDir = ends.ok.reader.listdir           // no directory: none
    println(out.path.count, " ", out.exists, " ", noPath.count == 0, " ", noDir.count == 0)
    println(OS.rmdir("io_path.tmpdir/sub"), " ", OS.rmdir("io_path.tmpdir"))
    return 0
}
// out: 0
// out: io_path.tmpdir/sub/f.txt 5 true false true false
// out: true 384 true 2
// out: f.txt io_path.tmpdir/sub io_path.tmpdir/sub/f.txt/x String
// out: true true 1000000000.0 true
// out: io_path.tmpdir true false
// out: [sub]
// out: io_path.tmpdir/sub
// out: io_path.tmpdir/sub/f.txt
// out: io_path.tmpdir/sub/f.txt
// out: true String
// out: true io_path.tmpdir/sub/g.txt true
// out: true false 2
// out: 0 false true true
// out: 0 0
// c: kv_io_open("io_path.tmpdir", "r")
// c: kv_io_rename((kv_io *)&m, "io_path.tmpdir/sub/g.txt")
