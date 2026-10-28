// f.lines gives each line as a Result<String, i64> and f.string the rest
// as one (#406): err the offset where the UTF-8 breaks, in the line or in
// what was read, to handle instead of dying of
#import <IO>
#import <stdio.h> as C
let path := "io_lines_result.tmp"
let whole(f:IO^):Result<int64, int64> {
    let s = try f^.string                // the err passed up, an i64 too
    return s.count as int64
}
let main():int32 {
    var w = IO(path, "w")
    var b = Bytes("ok line\n")
    b += Bytes([0xFF, 'b', 'a', 'd', '\n', 'a', 'b', 0xC3, '\n', '\n'])
    b += "last"
    w.write(&b)
    w.close()
    var f = IO(path)
    var n = 0
    for r in f.lines {
        n += 1
        if let line = r { println(n, ": [", line, "] ", line.count) } else { println(n, ": not UTF-8 at byte ", r.err) }
    }
    f.rewind()
    for r in f.lines { print(r.is(ok) ? "o" : "e") }
    println()
    var g = IO(path)
    var s = g.string
    println(s, " ", s.is(err))
    var h = IO(path)
    println(whole(&h))
    var k = IO("io_lines_result.k.tmp", "w")
    k.write("héllo\nworld")
    k.close()
    var t = IO("io_lines_result.k.tmp")
    println(whole(&t))
    remove(path)
    remove("io_lines_result.k.tmp")
    return 0
}
// out: 1: [ok line] 7
// out: 2: not UTF-8 at byte 0
// out: 3: not UTF-8 at byte 2
// out: 4: [] 0
// out: 5: [last] 4
// out: oeeoo
// out: err(8) true
// out: err(8)
// out: ok(11)
