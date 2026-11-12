// b.flip() of a bool (#454); x.bits[n] of an integer, its bit n a bool,
// set with =, |=, &= and ~=, and x.bits[n].flip() (#530); b.bits[n].flip()
// of a BigInt (#531), its place an enum's value too
enum flag { ready, busy, done }
struct holder { x: i32; on: bool }
let main():int32 {
    var b = true
    b.flip()                                  // b = !b
    var x:i32 = 5
    x.bits[1].flip()                                 // 0b101 to 0b111
    var u:u8 = 0
    u.bits[7] = true
    u.bits[0] |= true
    u.bits[7] &= false
    u.bits[3] ~= true                          // 0b1001
    var n:i64 = -1
    n.bits[63] = false                         // the sign bit
    var h:holder = {0, false}
    h.x.bits[31] = true
    h.on.flip()
    var bs = 0n
    bs.bits[busy].flip()                      // bit 1, busy's
    bs.bits[3].flip()
    var flags = $[true, false]
    flags[1].flip()
    var big:u128 = 1
    big.bits[127].flip()
    let k:i32 = 6
    println(b, " ", x, " ", u, " ", n, " ", h.x, " ", h.on, " ", bs, " ", flags)
    println(big.bits[127], " ", big.bits[0], " ", k.bits[1], " ", k.bits[0], " ", 5.bits[2], " ", x.bits[busy], " ", (k + 1).bits[0])
    return 0
}
// out: false 7 9 9223372036854775807 -2147483648 true 10n [true, true]
// out: true true true false true true true
