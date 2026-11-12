// x.bits of an integer (#530): its width of bools, an Array<bool>, place 0
// first, a copy; x.bits[n] its bit n, with no Array made; T(bools), the
// way back, of a [bool] written, a fixed array and an Array<bool>; an
// enum's value an i32's; arithmetic with a literal of C's width
enum flag { ready, busy, done }
enum limit { LOW = 5, HIGH }
let main():int32 {
    var x:u8 = 0b101
    var bs = x.bits
    println(bs, " ", bs.count, " ", x.bits == bs)
    bs[1] = true                              // the copy's: x stays
    bs.append(true)
    println(x, " ", u16(bs), " ", u8(x.bits), " ", x.bits[busy], " ", x.bits[done])
    var ones = 0
    for b in x.bits { if b { ones += 1 } }
    let n:i8 = -2
    let fixed:[bool](3) = [true, true, false]
    println(ones, " ", n.bits, " ", i8(n.bits), " ", u8([false, true]), " ", i64(fixed), " ", u8([]))
    let big:u128 = 1
    let y:i16 = 3
    println(big.bits.count, " ", y.bits.count, " ", (x + 1).bits.count, " ", 7.bits.count, " ", LOW.bits.count, " ", i32(LOW.bits), " ", u128(big.bits) == big)
    println(`${x.bits[0]} ${y.bits}`, " ", x.bits[0..<3])
    return 0
}
// out: [true, false, true, false, false, false, false, false] 8 true
// out: 5 263 5 false true
// out: 2 [false, true, true, true, true, true, true, true] -2 2 3 0
// out: 128 16 32 64 32 5 true
// out: true [true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false] [true, false, true]
