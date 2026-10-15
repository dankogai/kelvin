// f.byte (#85): the next byte, an Optional, none at the end. Numbers
// are read as lines, or the whole text, and converted (#88): scanf is
// no reader for Kelvin
#import <stdio.h> as C
#import <IO>
let path := "io_read_number.tmp"
let fill():Result<i64, i32> {
    let f = IO(path, "w")
    f.print("ab\n42\n-7\n3.5\nx\n9")
    return 0
}
let main():i32 {
    var w = fill()
    println(w.cstr)
    var f = IO(path, "r")
    if f.error == 0 {
        var b1 = f.byte
        var b2 = f.byte
        var b3 = f.byte
        println(b1.cstr, " ", b2.cstr, " ", b3.cstr, " ", b1.typename)
        var sum:int64 = 0
        var total = 0.0
        for line in f.lines {
            sum += i64(line)                 // 0 for a line with no number
            total += f64(line)
        }
        println(sum, " ", total)
        var end = f.byte
        println(end.cstr, " ", f.eof)
    }
    remove(path)
    return 0
}
// out: ok(0)
// out: some(97) some(98) some(10) u8?
// out: 47 47.5
// out: none true
// c: kv_io_read_byte((kv_io *)&f, &_kv_v) ? _kv__kv_opt_u8_make_some(_kv_v) : _kv__kv_opt_u8_make_none();
