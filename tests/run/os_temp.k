// OS.mkstemp(prefix) (#97): a temporary file made and opened for you,
// {io: IO, path: String} in a Result, in OS.tmpdir unless the prefix
// names a place; OS.mkdtemp(prefix): a temporary directory, its path
#import <errno.h> as C
let main():i32 {
    var t = OS.mkstemp("kelvin_test_")
    println(t.typename)
    if t.is(ok) {
        var dir = OS.dirname(t.ok.path)
        var tmp = String(OS.tmpdir)
        println(OS.isfile(t.ok.path), " ", dir == tmp, " ", t.ok.io.fd > 2)
        t.ok.io.println("written through the IO")
        t.ok.io.flush()
        var back = IO(t.ok.path, "r")
        if let ok(f) = back { for line in f.lines { println(line) } }
        t.ok.io.rewind()
        var same = t.ok.io.string
        print(same.ok)
        println(OS.remove(t.ok.path), " ", OS.exists(t.ok.path))
    }
    var d = OS.mkdtemp("kelvin_dir_")
    if let ok(p) = d {
        var name = OS.basename(p)
        println(OS.isdir(p), " ", name.count == 17, " ", OS.rmdir(p), " ", OS.exists(p))
    }
    var here = OS.mkdtemp("./os_temp_")
    if let ok(p) = here {
        var where = OS.dirname(p)
        println(where, " ", OS.rmdir(p))
    }
    var bad = OS.mkstemp("/no/such/dir/x")
    var badDir = OS.mkdtemp("/no/such/dir/x")
    println(bad.is(err), " ", bad.err == ENOENT, " ", badDir.is(err))
    return 0
}
// out: Result<{io: IO, path: String}, i32>
// out: true true true
// out: written through the IO
// out: written through the IO
// out: 0 false
// out: true true 0 false
// out: . 0
// out: true true true
// c: kv_os_mkstemp("kelvin_test_", &_kv_t.io, &_kv_t.path)
// c: kv_os_mkdtemp("kelvin_dir_", &_kv_s)
