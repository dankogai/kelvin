// IO(path, mode) straight (#109): the IO, with f.error the errno when it
// did not open, 0 otherwise; such an IO is as a closed one, f.fd -1, its
// path kept, its reads none, and f.error is passed up by hand with
// err(f.error); reading it by .lines or writing to it ends the program
#import <errno.h> as C
#import <IO>
let count(path:cstr):Result<i64, i32> {
    let f = IO(path)
    if f.error != 0 { return err(f.error) }
    var n:i64 = 0
    for line in f.lines { n += 1 }
    return n
}
let main():i32 {
    var w = IO("io_error.tmp", "w")
    w.println("one")
    w.println("two")
    w.println("three")
    w.close()
    let f = IO("io_error.tmp")
    println(f.error, " ", f.fd > 2, " ", f.typename, " ", f.stat.size)
    var g = IO("/no/such", "r")
    var gb = g.bytes
    println(g.error == ENOENT, " ", g.fd, " ", g.path, " ", gb.count, " ", g.eof, " ", g.exists, " ", g.stat.size)
    var h = IO(99, "r")
    println(h.error == EBADF, " ", h.path.count)
    var c = count("io_error.tmp")
    var d = count("/no/such")
    println(c.cstr, " ", d.cstr, " ", d.err == ENOENT)
    g.close()
    println(g.error == ENOENT)                   // kept through close
    println(OS.remove("io_error.tmp"))
    return 0
}
// out: 0 true IO 14
// out: true -1 /no/such 0 false false 0
// out: true 0
// out: ok(3) err(2) true
// out: true
// out: 0
// c: kv_io f = kv_io_open("io_error.tmp", "r")
// c: kv_io_error((kv_io *)&g)
