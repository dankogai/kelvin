// Bits (#387): 64 bits in a u64, '.value', each bit a bool by its place,
// 0 the lowest; bv[n] read, and set with =, |=, &= and ~= of a bool; the
// whole as a u64 is, | & ~ (xor) << >> == != and their assignments, ~bv;
// bv.flip(n); an enum names the flags; printed as Bits(0b...), which pastes
// back; no C bit-field
enum flag { ready, busy, done }
struct job { id: int64; flags: Bits }
let twice(b:Bits):Bits { return b << 1 }
let main():int32 {
    var bv = Bits()
    bv[0] = !!1
    bv[3] = true
    bv[busy] |= true
    println(bv, " ", bv.value, " ", bv[0], " ", bv[2], " ", bv[busy])
    bv[0] &= false
    bv[5] ~= true
    bv.flip(6)
    println(bv, " ", bv.cstr, " ", `${bv}`)
    let a = Bits(0b1100)
    let b:Bits = Bits(0b1010)
    println(a | b, " ", a & b, " ", a ~ b, " ", ~a == (Bits(-1) ~ a), " ", a << 2, " ", a >> 3, " ", a == b, " ", a != b)
    var c = a
    c |= b
    c <<= 1
    c.value += 3
    println(c, " ", c.value, " ", Bits(), " ", twice(Bits(5)))
    let all = Bits(0b1111111111111111111111111111111111111111111111111111111111111111)
    println(all == Bits(-1), " ", all.value, " ", all[63], " ", Bits(1) << 63)
    var xs:$[Bits] = $[Bits(1), Bits(2)]
    xs += Bits(4)
    let o:Bits? = Bits(3)
    let j:job = {7, Bits(5)}
    println(xs, " ", xs[1][1], " ", o, " ", j, " ", Bits(5).typename)
    return 0
}
// out: Bits(0b1011) 11 true false true
// out: Bits(0b1101010) Bits(0b1101010) Bits(0b1101010)
// out: Bits(0b1110) Bits(0b1000) Bits(0b110) true Bits(0b110000) Bits(0b1) false true
// out: Bits(0b11111) 31 Bits(0b0) Bits(0b1010)
// out: true 18446744073709551615 true Bits(0b1000000000000000000000000000000000000000000000000000000000000000)
// out: [Bits(0b1), Bits(0b10), Bits(0b100)] true some(Bits(0b11)) {id: 7, flags: Bits(0b101)} Bits
// c: kv_bits_put(&(bv), (uint64_t)(0), KV_BIT_OF(1))
// c: kv_bits_flip(&(bv), (uint64_t)(6))
