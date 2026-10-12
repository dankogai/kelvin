// f.byte, f.i64 and f.f64 (#85): the next byte, integer or float, an
// Optional, none at the end or where no number is there; numbers as
// scanf reads them, spaces skipped
#import <stdio.h> as C
let path := "io_read_number.tmp"
let fill():Result<i64, i32> {
    let f = try IO(path, "w")
    f.print("ab 42 -7\n3.5 x 9")
    return 0
}
let main():i32 {
    var w = fill()
    println(w.cstr)
    var r = IO(path, "r")
    if let ok(f) = r {
        var b1 = f.byte
        var b2 = f.byte
        println(b1.cstr, " ", b2.cstr, " ", b1.typename)
        var n1 = f.i64
        var n2 = f.i64
        var n3 = f.i64                   // "3.5": 3, leaving ".5"
        var x = f.f64                    // .5
        var bad = f.i64                  // "x": none, and x stays
        var bad2 = f.f64
        println(n1.cstr, " ", n2.cstr, " ", n3.cstr, " ", x.cstr, " ", bad.cstr, " ", bad2.cstr, " ", x.typename)
        var c = f.byte                   // ' ' before x? no: scanf skipped it; 'x' itself
        var last = f.i64
        var end = f.byte
        var endn = f.i64
        println(c.cstr, " ", last.cstr, " ", end.cstr, " ", endn.cstr, " ", f.eof)
        var sum:i64 = 0
        f.rewind()
        f.seek(2)
        while true {
            if let n = f.i64 { sum += n } else { break }
        }
        println(sum)
    }
    remove(path)
    return 0
}
// out: ok(0)
// out: some(97) some(98) u8?
// out: some(42) some(-7) some(3) some(0.5) none none f64?
// out: some(120) some(9) none none true
// out: 38
// c: kv_io_read_i64((kv_io *)&f, &_kv_v) ? _kv__kv_opt_i64_make_some(_kv_v) : _kv__kv_opt_i64_make_none();
