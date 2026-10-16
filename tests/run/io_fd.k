// IO(fd, mode) (#86): a file descriptor's IO, as fdopen gives it, told
// from a path by the argument's type; f.fd is the descriptor; a bad
// descriptor leaves f.error EBADF (#109)
#import <errno.h> as C
#import <stdio.h> as C
#import <IO>
let path := "io_fd.tmp"
let fill():Result<int64, int32> {
    let f = IO(path, "w")
    f.println("through a descriptor")
    println(f.fd > 2)
    return 0
}
let main():int32 {
    var w = fill()
    println(w.cstr)
    var f = IO(path, "r")
    if f.error == 0 {
        let fd:int32 = f.fd
        var g = IO(fd, "r")                      // a second IO on the same descriptor
        if g.error == 0 {
            println(g.fd == fd, " ", g.typename)
            for line in g.lines { println(line) }
        }
    }
    var bad = IO(99, "r")
    println(bad.error == EBADF, " ", bad.fd)
    var closed = IO(path, "r")
    if closed.error == 0 {
        closed.close()
        println(closed.fd)
    }
    remove(path)
    return 0
}
// out: true
// out: ok(0)
// out: true IO
// out: through a descriptor
// out: true -1
// out: -1
// c: kv_io_fdopen(fd, "r")
// c: kv_io_fd((kv_io *)&f)
