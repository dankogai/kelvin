// a struct defines & | ~ (xor) << >> and unary ~ (#502), with C's
// precedence; x &= y, x |= y, x ~= y, x <<= n and x >>= n are x = x op y;
// the operands are lent (#501), and an enum with values defines them too
struct W { limbs: $[u64] }
extend W {
    static let of(n:u64):Self {
        var r:$[u64] = $[]
        r += n
        return (Self){r.copy()}
    }
    static let &(a:Self, b:Self):Self { W.of(a.limbs[0] & b.limbs[0]) }
    static let |(a:Self, b:Self):Self { W.of(a.limbs[0] | b.limbs[0]) }
    static let ~(a:Self, b:Self):Self { W.of(a.limbs[0] ~ b.limbs[0]) }
    static let ~(a:Self):Self { W.of(~a.limbs[0]) }
    static let <<(a:Self, n:int64):Self { W.of(a.limbs[0] << n) }
    static let >>(a:Self, n:int64):Self { W.of(a.limbs[0] >> n) }
}
struct m4 { v: u8 }
let &(a:m4, b:m4):m4 { (m4){a.v & b.v} }
let ~(a:m4):m4 { (m4){~a.v & 15} }
enum flags { none; bits: u8 }
let |(a:flags, b:flags):flags {
    if a.is(bits) && b.is(bits) { return flags.bits(a.bits | b.bits) }
    return flags.none
}
let main():int32 {
    let a = W.of(12)
    let b = W.of(10)
    println((a & b).limbs, " ", (a | b).limbs, " ", (a ~ b).limbs, " ", (~a).limbs[0] == ~(12 as u64), " ", (a << 2).limbs, " ", (a >> 2).limbs)
    var z = W.of(1)
    z <<= 4
    z |= a
    z &= W.of(29)
    z ~= b
    z >>= 1
    println(z.limbs, " ", (a & b | a << 1 ~ b).limbs, " ", a.limbs)
    var x:m4 = {6}
    x &= (m4){3}
    println((~x).v, " ", x.v, " ", 1 << 3 | 1)
    var f = flags.bits(1)
    f |= flags.bits(4)
    println(f, " ", f | flags.none)
    return 0
}
// out: [8] [14] [6] true [48] [3]
// out: [11] [26] [12]
// out: 13 2 9
// out: flags.bits(5) flags.none
// c: _kv_shl_op__W__i64(
