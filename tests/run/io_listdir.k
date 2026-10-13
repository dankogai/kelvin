// an open directory's names, paths and matches straight (#106): f.listdir,
// f.walk and f.glob(pattern) give an Array<String> with no Result, since
// the directory was there to open; renamed behind the IO, it answers by
// the descriptor's name (#105); an IO that is no readable directory, or
// nothing, gives none
let main():i32 {
    println(OS.makedirs("io_listdir.tmpdir/sub"))
    var f = IO("io_listdir.tmpdir/sub/f.txt", "w")
    if f.error == 0 {
        f.write("x")
        var names = f.listdir                    // a file: no names
        var under = f.walk
        var none = f.glob("*")
        println(names.count, " ", under.count, " ", none.count, " ", names.typename)
    }
    var dir = IO("io_listdir.tmpdir")
    if dir.error == 0 {
        var names = dir.listdir
        for n in names { print("[", n, "]") }
        println()
        var all = dir.walk                       // an owner an expression gives: bound, as ever
        for p in all { println(p) }
        var txt = dir.glob("*/*.txt")
        for p in txt { println(p) }
        println(OS.rename("io_listdir.tmpdir", "io_listdir.moved"), " ", dir.exists)   // the path is stale
        var cwd = OS.cwd
        var moved = OS.join(cwd.ok, "io_listdir.moved")
        var still = dir.listdir                  // by the descriptor's name
        for n in still { print("[", n, "]") }
        println()
        var sub = OS.join(moved, "sub")
        var file = OS.join(sub, "f.txt")
        var under = dir.walk
        println(under.count, " ", under[0] == sub, " ", under[1] == file)
        var matches = dir.glob("sub/*.txt")
        println(matches.count, " ", matches[0] == file)
    }
    var ends = IO.pipe()
    if ends.reader.error == 0 {
        var names = ends.reader.listdir
        println(names.count)
    }
    println(OS.remove("io_listdir.moved/sub/f.txt"), " ", OS.rmdir("io_listdir.moved/sub"), " ", OS.rmdir("io_listdir.moved"))
    return 0
}
// out: 0
// out: 0 0 0 Array<String>
// out: [sub]
// out: io_listdir.tmpdir/sub
// out: io_listdir.tmpdir/sub/f.txt
// out: io_listdir.tmpdir/sub/f.txt
// out: 0 false
// out: [sub]
// out: 2 true true
// out: 1 true
// out: 0
// out: 0 0 0
// c: kv_io_listdir((kv_io *)&dir, &_kv_at, &_kv_n)
