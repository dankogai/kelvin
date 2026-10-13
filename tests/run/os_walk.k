// OS.walk(path) (#96): every path under a directory, each level's names
// sorted, depth first, links not followed, a Result<Array<String>, i32>;
// OS.glob(pattern): the paths a shell pattern matches, sorted, none
// where none match
#import <errno.h> as C
let main():i32 {
    println(OS.makedirs("os_walk.tmpdir/a/b"), " ", OS.makedirs("os_walk.tmpdir/c"))
    var files = $["os_walk.tmpdir/a/b/f.txt", "os_walk.tmpdir/a/g.txt", "os_walk.tmpdir/h.txt", "os_walk.tmpdir/c/i.md"]
    for p in files {
        var f = IO(p, "w")
        f.write("x")
        f.close()
    }
    var all = OS.walk("os_walk.tmpdir")
    if let ok(ps) = all { for p in ps { println(p) } }
    println(all.typename)
    var txt = OS.glob("os_walk.tmpdir/*/*.txt")
    if let ok(ps) = txt { for p in ps { println(p) } }
    var top = OS.glob("os_walk.tmpdir/*")
    if let ok(ps) = top { println(ps.count) }
    var none = OS.glob("os_walk.tmpdir/*.nothing")
    println(none.is(ok), " ", none.ok.count)
    var missing = OS.walk("os_walk.tmpdir/none")
    println(missing.is(err), " ", missing.err == ENOENT)
    var pattern = $"os_walk.tmpdir/?.txt"
    var one = OS.glob(pattern)
    if let ok(ps) = one { println(ps.count, " ", ps[0]) }
    for p in files { OS.remove(p) }
    println(OS.rmdir("os_walk.tmpdir/a/b"), " ", OS.rmdir("os_walk.tmpdir/a"), " ", OS.rmdir("os_walk.tmpdir/c"), " ",
            OS.rmdir("os_walk.tmpdir"))
    return 0
}
// out: 0 0
// out: os_walk.tmpdir/a
// out: os_walk.tmpdir/a/b
// out: os_walk.tmpdir/a/b/f.txt
// out: os_walk.tmpdir/a/g.txt
// out: os_walk.tmpdir/c
// out: os_walk.tmpdir/c/i.md
// out: os_walk.tmpdir/h.txt
// out: Result<Array<String>, i32>
// out: os_walk.tmpdir/a/g.txt
// out: 3
// out: true 0
// out: true true
// out: 1 os_walk.tmpdir/h.txt
// out: 0 0 0 0
// c: kv_os_walk("os_walk.tmpdir", &_kv_at, &_kv_n)
// c: kv_os_glob("os_walk.tmpdir/*/*.txt", &_kv_at, &_kv_n)
