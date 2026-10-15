// f.print(...) and f.println(...) (#83): as print and println, to an IO:
// numbers, floats, bools, text, Strings, Bytes, a uchr, a struct's text,
// up to 16 values, nothing at all; to a file, to IO.stderr, to IO.stdout
#import <stdio.h> as C
#import <IO>
struct point { x: int32; y: i32 }
let path := "io_print.tmp"
let write_it():Result<i64, i32> {
    let f = IO(path, "w")
    let p:point = {3, 4}
    var s = $"héllo"
    var b = Bytes("raw")
    f.println("n = ", 42, ", half = ", 42 / 2.0, " ", true, " ", 'x', " ", 255 as u8)   // 'x' is a u8, 120
    f.println(s, " ", b, " ", p.cstr, " ", s.count)
    for c in s { f.print(c, "|") }
    f.println()
    f.println(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)
    f.print("no newline")
    return 0
}
let main():i32 {
    var w = write_it()
    println(w.cstr)
    var f = IO(path, "r")
    if f.error == 0 {
        for line in f.lines { println("[", line, "]") }
    }
    IO.stderr.println("to stderr ", 1)
    IO.stdout.println("to stdout ", 2.5)
    var out = IO.stdout
    out.print("bound ", 3)
    out.println()
    remove(path)
    return 0
}
// out: ok(0)
// out: [n = 42, half = 21.0 true 120 255]
// out: [héllo raw {x: 3, y: 4} 5]
// out: [h|é|l|l|o|]
// out: [12345678910111213141516]
// out: [no newline]
// out: to stdout 2.5
// out: bound 3
// c: KV_FPRINTLN((kv_io *)&f, "n = ", 42
// c: KV_FPRINT((kv_io *)&out, "bound ", 3)
// c: KV_FPRINTLN((kv_io *)&(*kv_io_std(1)), "to stdout ", 2.5)
