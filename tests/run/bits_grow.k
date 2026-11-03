// a Bits grows past 64 bits (#455): made of bools, [bool]s, integers, each
// its type's width, and text "0b...", in turn from place 0; .append of the
// same, .capacity(n) in bits, a multiple of 64; .u64s and .bin; for b in
// bv; .count, .isEmpty
let main():int32 {
    var big = Bits(-1, u8(1), true, "0b10", [true, false])
    println(big.count, " ", big.u64s, " ", big.bin, " ", big[64], " ", big[70])
    big.append(false)
    big.append([true, true])
    big.append(i16(-1))
    big.append("0b0")
    big.capacity(300)
    println(big.count, " ", big.capacity, " ", big.u64s.count, " ", big.isEmpty, " ", Bits().isEmpty)
    var ones = 0
    for bit in big { if bit { ones += 1 } }
    let s = $"0b1001"
    let fx:[bool](3) = [true, true, false]
    let arr = $[false, true]
    println(ones, " ", Bits(&s), " ", Bits(s), " ", Bits(fx), " ", Bits(arr), " ", Bits(u8(1)) | Bits(u16(2)))
    let back = Bits("0b100000000000000000000000000000000000000000000000000000000000000000000000001")
    println(back.count, " ", back.u64s, " ", back == Bits(1, "0b10000000000"))
    var empty = Bits()
    empty <<= 3
    println(empty, " ", Bits("0b1") << 2, " ", (Bits("0b101") >> 5).count, " ", Bits(u8(255)).bin, " ", Bits().bin.count)
    return 0
}
// out: 77 [18446744073709551615, 3329] ["0b1111111111111111111111111111111111111111111111111111111111111111", "0b0110100000001"] true false
// out: 97 320 2 false true
// out: 86 Bits("0b1001") Bits("0b1001") Bits("0b011") Bits("0b10") Bits("0b0000000000000011")
// out: 75 [1, 1024] true
// out: Bits() Bits("0b100") 0 ["0b11111111"] 0
