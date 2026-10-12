// IO(fd, mode) (#86): a file descriptor's IO, as fdopen gives it, told
// from a path by the argument's type; f.fd is the descriptor; a bad
// descriptor is an err
#import <errno.h> as C
#import <stdio.h> as C
let path := "io_fd.tmp"
let fill():Result<i64, i32> {
    let f = try IO(path, "w")
    f.println("through a descriptor")
    println(f.fd > 2)
    return 0
}
let main():i32 {
    var w = fill()
    println(w.cstr)
    var a = IO(path, "r")
    if let ok(f) = a {
        let fd:i32 = f.fd
        var b = IO(fd, "r")                      // a second IO on the same descriptor
        if let ok(g) = b {
            println(g.fd == fd, " ", g.typename)
            for line in g.lines { println(line) }
        }
    }
    var bad = IO(99, "r")
    println(bad.is(err), " ", bad.err == EBADF)
    var closed = IO(path, "r")
    if closed.is(ok) {
        closed.ok.close()
        println(closed.ok.fd)
    }
    remove(path)
    return 0
}
// out: true
// out: ok(0)
// out: true IO
// out: through a descriptor
// out: true true
// out: -1
// c: kv_io_fdopen(&_kv_f, fd, "r")
// c: kv_io_fd((kv_io *)&f)
