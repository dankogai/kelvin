// b.flip() of a bool; x.flip(n) and x.bit(n) of an integer, its bit n a
// bool, set with =, |=, &= and ~=; bv[n].flip() of a Bits (#454)
enum flag { ready, busy, done }
struct holder { x: i32; on: bool }
let main():int32 {
    var b = true
    b.flip()                                  // b = !b
    var x:i32 = 5
    x.flip(1)                                 // 0b101 to 0b111
    var u:u8 = 0
    u.bit(7) = true
    u.bit(0) |= true
    u.bit(7) &= false
    u.bit(3) ~= true                          // 0b1001
    var n:i64 = -1
    n.bit(63) = false                         // the sign bit
    var h:holder = {0, false}
    h.x.bit(31) = true
    h.on.flip()
    var bs = Bits()
    bs[busy].flip()                           // bs.flip(busy)
    bs[3].flip()
    var flags = $[true, false]
    flags[1].flip()
    var big:u128 = 1
    big.flip(127)
    let k:i32 = 6
    println(b, " ", x, " ", u, " ", n, " ", h.x, " ", h.on, " ", bs, " ", flags)
    println(big.bit(127), " ", big.bit(0), " ", k.bit(1), " ", k.bit(0), " ", 5.bit(2), " ", x.bit(busy), " ", (k + 1).bit(0))
    return 0
}
// out: false 7 9 9223372036854775807 -2147483648 true Bits(0b1010) [true, true]
// out: true true true false true true true
