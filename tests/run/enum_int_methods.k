// an enum's value is C's int, an i32 to an integer's methods (#469):
// .bit(n), .flip(n), .abs, .sign, .pow, ** and .size of an enum's
// constant and of a var of its enum
enum limit { LOW = 5, HIGH }
let main():int32 {
    let f:limit = LOW
    var v:limit = LOW
    v.flip(0)                                 // 5 to 4
    var w:limit = HIGH
    w.bit(0) = true                           // 6 to 7
    println(LOW.bit(2), " ", LOW.bit(1), " ", f.bit(0), " ", v as i32, " ", w as i32)
    println(LOW.abs, " ", f.sign, " ", HIGH.pow(2), " ", HIGH.pow(2, 5), " ", LOW ** 2, " ", LOW.size)
    println(LOW.hex, " ", HIGH.dec)
    return 0
}
// out: true false true 4 7
// out: 5 1 36 1 25 4
// out: +0x5 +6
