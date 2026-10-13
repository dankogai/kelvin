// an IO's position (#84): .eof once a read has met the end, .position
// and .count in bytes, .seek(n) from the start (a bool), .rewind()
#import <stdio.h> as C
let path := "io_seek.tmp"
let fill():Result<i64, i32> {
    let f = IO(path, "w")
    f.print("0123456789\n")
    println(f.position, " ", f.count)
    return 0
}
let main():i32 {
    var w = fill()
    println(w.cstr)
    var f = IO(path, "r")
    if f.error == 0 {
        println(f.count, " ", f.position, " ", f.eof)
        for chunk in f.read(4) {
            print("[", chunk, "]", f.position, " ")
            break
        }
        println(f.seek(8), " ", f.position)
        for chunk in f.read(100) { print("[", chunk, "]") }
        println(f.eof)
        f.rewind()
        println(f.eof, " ", f.position, " ", f.seek(5))
        for line in f.lines { println(line) }
        println(f.eof, " ", f.seek(-1), " ", f.seek(100), " ", f.position)
    }
    remove(path)
    return 0
}
// out: 11 11
// out: ok(0)
// out: 11 0 false
// out: [0123]4 true 8
// out: [89
// out: ]true
// out: false 0 true
// out: 56789
// out: true false true 100
// c: kv_io_seek((kv_io *)&f, 8)
// c: kv_io_eof((kv_io *)&f)
