// IO.popen(command, mode) (#87): a process's IO, read or written, its
// block waiting for it, and .status its exit code once closed; IO.pipe()
// a {reader: IO, writer: IO}, each end an IO
#import <stdio.h> as C
let path := "io_process.tmp"
let main():i32 {
    var p = IO.popen("printf 'one\\ntwo\\n'", "r")
    if p.is(ok) {
        for line in p.ok.lines { println("[", line, "]") }
        println(p.ok.status)                // -1 until closed
        p.ok.close()
        println(p.ok.status, " ", p.ok.fd)  // the exit code, 0
    }
    var e = IO.popen("exit 3", "r")
    if e.is(ok) {
        e.ok.close()
        println(e.ok.status)
    }
    var w = IO.popen("cat > io_process.tmp", "w")
    if w.is(ok) {
        w.ok.println("via a process ", 42)
        w.ok.close()
        println(w.ok.status)
    }
    var back = IO(path, "r")
    for line in back.lines { println(line) }
    println(back.status)                    // not a process
    var pipe = IO.pipe()
    if let ok(ends) = pipe {
        println(pipe.typename, " ", ends.reader.fd >= 0, " ", ends.writer.fd >= 0)
    }
    if pipe.is(ok) {
        pipe.ok.writer.println("through a pipe")
        pipe.ok.writer.close()
        for line in pipe.ok.reader.lines { println(line) }
    }
    var cmd = $"printf 'from a String'"
    var s = IO.popen(cmd, "r")
    if let ok(f) = s {
        var all = f.string                       // a String straight (#107)
        println(all)
    }
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
// out: Result<{reader: IO, writer: IO}, i32> true true
// out: through a pipe
// out: from a String
// c: kv_io_popen(&_kv_f, "printf 'one\\ntwo\\n'", "r")
// c: kv_io_pipe(&_kv_p.reader, &_kv_p.writer)
