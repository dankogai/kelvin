// f.isatty (#103): whether an IO's descriptor is a terminal, false for
// a file, a pipe, a closed IO, and a stream that is redirected, as the
// tests' stdout is; IO.strerror(err): the message for an err, a String
#import <errno.h> as C
let main():i32 {
    var f = IO("io_isatty.k.none", "r")
    if let err(e) = f {
        var why = IO.strerror(e)
        println(why)
    }
    var msg = IO.strerror(ENOENT)
    println(msg, " ", msg.typename)
    var out = IO.stdout
    println(out.isatty)
    var p = IO.pipe()
    if let ok(ends) = p { println(ends.reader.isatty, " ", ends.writer.isatty) }
    var t = OS.mkstemp("io_isatty_")
    if t.is(ok) {
        println(t.ok.io.isatty)
        var path = t.ok.path.copy()
        t.ok.io.close()
        println(t.ok.io.isatty, " ", OS.remove(path))
    }
    return 0
}
// out: No such file or directory
// out: No such file or directory String
// out: false
// out: false false
// out: false
// out: false 0
// c: kv_io_isatty((kv_io *)&out)
// c: kv_os_strerror(ENOENT)
