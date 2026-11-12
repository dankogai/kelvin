// b.bits of a BigInt (#531): its bits in the shortest two's complement
// form, an Array<bool>, place 0 first, the last its sign, a copy;
// b.bits[n] its bit n where it is, with no Array made, past its top the
// sign; set with =, |=, &= and ~= of a bool, and flipped, in the var that
// holds it, which grows; BigInt(bools), the way back, of an Array<bool>,
// a [bool] written and a fixed array
enum flag { lo = 1, hi = 4 }
struct acct { id: i64; mask: BigInt }
let low(b:lent BigInt):bool { b.bits[0] }
let raise(b:BigInt^, n:i64) { b^.bits[n] = true }
let twice(b:lent BigInt):BigInt { b + b }
let main():int32 {
    var b = 5n
    let m = -6n
    println(b.bits, " ", m.bits, " ", 0n.bits, " ", (-1n).bits, " ", (1n << 63).bits.count)
    println(b.bits[0], " ", b.bits[1], " ", b.bits[2], " ", b.bits[3], " ", b.bits[100])
    println(m.bits[0], " ", m.bits[1], " ", m.bits[2], " ", m.bits[3], " ", m.bits[100])
    var bs = b.bits
    bs[1] = true                              // the copy's: b stays
    println(b, " ", BigInt(bs), " ", BigInt(b.bits) == b, " ", BigInt(m.bits) == m)
    b.bits[1] = true
    b.bits[100] = true                        // past its top: b grows
    println(b, " ", b.bits.count)
    b.bits[100] = false
    b.bits[0].flip()
    b.bits[3] |= true
    b.bits[1] &= false
    b.bits[2] ~= true
    println(b, " ", (b + 1n).bits[0], " ", twice(b).bits[4], " ", low(b))
    b.bits[hi] = true                         // an enum's value its place
    raise(&b, 200)
    println(b.bits[lo], " ", b.bits.count, " ", b.bits[200], " ", b.bits[199], " ", b.text(16))
    var neg = -1n
    neg.bits[70] = false                      // a negative one stays negative
    println(neg, " ", neg == -1n - (1n << 70), " ", neg.bits[1000])
    neg.bits[70].flip()
    neg.bits[0] = false
    println(neg, " ", neg.bits)
    var z = 0n
    z.bits[63] = true                         // 2 ** 63, of two limbs
    println(z, " ", z.bits.count)
    var a:acct = {1, 0n}
    for i in 0..<5 { a.mask.bits[i * 2] = true }
    let n:u64 = 3
    a.mask.bits[n].flip()
    var ones = 0
    for bit in a.mask.bits { if bit { ones += 1 } }
    println(a.mask, " ", a.mask.bits, " ", ones)
    var xs = $[1n, 2n]
    xs[0].bits[5] = true
    let fixed:[bool](3) = [true, true, false]
    let t = true
    println(xs, " ", BigInt([true, false, true, false]), " ", BigInt([t, !t, 1 < 2]), " ", BigInt(fixed), " ", BigInt($[true, true, false]), " ", BigInt([]))
    println(u8(255n.bits[0..<8]), " ", BigInt(u8(200).bits), " ", BigInt(i8(-56).bits), " ", `${b.bits[0]} ${m.bits}`)
    return 0
}
// out: [true, false, true, false] [false, true, false, true] [false] [true] 65
// out: true false true false false
// out: false true false true true
// out: 5n 7n true true
// out: 1267650600228229401496703205383n 102
// out: 8n true true false
// out: false 202 true false 100000000000000000000000000000000000000000000000018
// out: -1180591620717411303425n true true
// out: -2n [false, true]
// out: 9223372036854775808n 65
// out: 349n [true, false, true, true, true, false, true, false, true, false] 6
// out: [33n, 2n] 5n -3n 3n 3n 0n
// out: 255 -56n -56n false [false, true, false, true]
