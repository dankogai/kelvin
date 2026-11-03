// Bits (#387, #455): bits in u64s, each a bool by its place, 0 the lowest;
// bv[n] read, and set with =, |=, &= and ~= of a bool; | & ~ (xor) of two,
// of the longer count, << and >> growing and shrinking it, == != and their
// assignments, ~bv; bv.flip(n); an enum names the flags; printed as
// Bits("0b..."), which pastes back; an owner; no C bit-field
enum flag { ready, busy, done }
struct job { id: int64; flags: Bits }
let twice(b:Bits):Bits { return b << 1 }
let main():int32 {
    var bv = Bits(u8(0))
    bv[0] = !!1
    bv[3] = true
    bv[busy] |= true
    println(bv, " ", bv.count, " ", bv[0], " ", bv[2], " ", bv[busy])
    bv[0] &= false
    bv[5] ~= true
    bv.flip(6)
    bv[7].flip()
    println(bv, " ", bv.cstr, " ", `${bv}`)
    let a = Bits("0b1100")
    let b:Bits = Bits([false, true, false, true])
    println(a | b, " ", a & b, " ", a ~ b, " ", ~a == Bits("0b0011"), " ", a << 2, " ", a >> 3, " ", a == b, " ", a != b)
    var c = a.copy()
    c |= b
    c <<= 1
    c >>= 2
    println(c, " ", c.count, " ", Bits(), " ", twice(Bits(u8(5))), " ", Bits("0b1") | Bits(u8(2)))
    let all = Bits(-1)
    println(all == Bits(u64(18446744073709551615)), " ", all.count, " ", all[63], " ", (Bits(1) << 63).count)
    var xs:$[Bits] = $[Bits(u8(1)), Bits(u8(2))]
    xs += Bits(u8(4))
    let o:Bits? = Bits("0b11")
    let j:job = {7, Bits("0b101")}
    println(xs, " ", xs[1][1], " ", o, " ", j, " ", Bits(5).typename)
    return 0
}
// out: Bits("0b00001011") 8 true false true
// out: Bits("0b11101010") Bits("0b11101010") Bits("0b11101010")
// out: Bits("0b1110") Bits("0b1000") Bits("0b0110") true Bits("0b110000") Bits("0b1") false true
// out: Bits("0b111") 3 Bits() Bits("0b000001010") Bits("0b00000011")
// out: true 64 true 127
// out: [Bits("0b00000001"), Bits("0b00000010"), Bits("0b00000100")] true some(Bits("0b11")) {id: 7, flags: Bits("0b101")} Bits
// c: kv_bits_put(&(bv), (int64_t)(0), KV_BIT_OF(1))
// c: kv_bits_flip(&(bv), (int64_t)(6))
