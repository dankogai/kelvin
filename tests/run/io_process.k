// IO.popen(command, mode) (#87): a process's IO, straight (#110), read or
// written, its block waiting for it, and .status its exit code once
// closed; IO.pipe() a {reader: IO, writer: IO}, each end an IO
#import <stdio.h> as C
let path := "io_process.tmp"
let main():i32 {
    var p = IO.popen("printf 'one\\ntwo\\n'", "r")
    if p.error == 0 {
        for line in p.lines { println("[", line, "]") }
        println(p.status)                // -1 until closed
        p.close()
        println(p.status, " ", p.fd)  // the exit code, 0
    }
    var e = IO.popen("exit 3", "r")
    if e.error == 0 {
        e.close()
        println(e.status)
    }
    var w = IO.popen("cat > io_process.tmp", "w")
    if w.error == 0 {
        w.println("via a process ", 42)
        w.close()
        println(w.status)
    }
    var back = IO(path, "r")
    for line in back.lines { println(line) }
    println(back.status)                    // not a process
    var pipe = IO.pipe()                                           // the pair straight (#110)
    println(pipe.typename, " ", pipe.reader.fd >= 0, " ", pipe.writer.fd >= 0, " ", pipe.reader.error)
    pipe.writer.println("through a pipe")
    pipe.writer.close()
    for line in pipe.reader.lines { println(line) }
    var cmd = $"printf 'from a String'"
    var s = IO.popen(cmd, "r")
    var all = s.string                           // a String straight (#107)
    println(all)
    remove(path)
    return 0
}
// out: [one]
// out: [two]
// out: -1
// out: 0 -1
// out: 3
// out: 0
// out: via a process 42
// out: -1
// out: {reader: IO, writer: IO} true true 0
// out: through a pipe
// out: from a String
// c: kv_io_popen("printf 'one\\ntwo\\n'", "r")
// c: kv_io_pipe(&_kv_p.reader, &_kv_p.writer)
