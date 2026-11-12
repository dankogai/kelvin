// an enum's value is C's int, an i32 to an integer's methods (#469):
// .bits[n], its .flip() (#530), .abs, .sign, .pow, ** and .size of an enum's
// constant and of a var of its enum
enum limit { LOW = 5, HIGH }
let main():int32 {
    let f:limit = LOW
    var v:limit = LOW
    v.bits[0].flip()                                 // 5 to 4
    var w:limit = HIGH
    w.bits[0] = true                           // 6 to 7
    println(LOW.bits[2], " ", LOW.bits[1], " ", f.bits[0], " ", v as i32, " ", w as i32)
    println(LOW.abs, " ", f.sign, " ", HIGH.pow(2), " ", HIGH.pow(2, 5), " ", LOW ** 2, " ", LOW.size)
    println(LOW.hex, " ", HIGH.dec)
    return 0
}
// out: true false true 4 7
// out: 5 1 36 1 25 4
// out: +0x5 +6
