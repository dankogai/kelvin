// +x of a struct (#563): x's value, where its type has a unary -, as a
// BigInt, a complex number and a rational have; a value and no place,
// so of a variable a copy, an owner's a new one as -x's is, and +1n of a
// literal is the literal; a BigInt's .hex, .oct and .bin, +0xffn, paste
// back
#import <BigNum>
struct vec { x:i32; y:i32 }
extend vec {
    static let -(a:Self):Self { (Self){-a.x, -a.y} }
    static let +(a:Self, b:Self):Self { (Self){a.x + b.x, a.y + b.y} }
}
struct box { v:vec; n:BigInt }
let twice(n:BigInt):BigInt { n + n }
let main():int32 {
    // a BigInt literal with a sign, in each base: the text of .hex, .oct and .bin
    println(+1n, " ", +0xffn, " ", +0o17n, " ", +0b101n, " ", + +1n, " ", +(+1n), " ", - +1n, " ", + -1n)
    println((255n).hex, " ", (+0xffn).hex, " ", (+0o377n).oct, " ", (+0b11111111n).bin, " ", +0xffn == 255n)
    println((+1n).typename, " ", +(1n << 70), " ", +(2n ** 64) - +1n, " ", 1n + +2n, " ", 1n - +2n)
    // of a variable: a new BigInt, the variable's own untouched
    var n = 5n
    var m = +n
    m += 1
    let k:BigInt = +n
    println(m, " ", n, " ", k, " ", m.typename, " ", +n + +n, " ", - +n, " ", + -n)
    println(twice(+n), " ", (+n).hex, " ", twice(+1n), " ", n)
    // of a member, and of what p^ points to
    var b = (box){{1, 2}, 7n}
    let q := &n
    var c = +b.n
    c += q^
    println(c, " ", b.n, " ", +q^, " ", +q^ * 2n)
    // a complex number's, and a struct's with a unary - of its own
    let z = c64(1.5, -2.0)
    let w = +z
    let v:vec = {3, 4}
    var u = +v
    u.x = 9
    println(w.real, " ", w.imag, " ", (+z).typename, " ", (+z).hex, " ", (+c32(1.0, 2.0)).dec)
    println(u.x, " ", v.x, " ", (+v + +v).y, " ", (+b.v).y, " ", (- +v).x, " ", (+ -v).x, " ", (+v).typename)
    // a rational's, at each width, and a BigRat's and a CBR's, owners both
    let r = rat64(1, 3)
    let s = BigRat(1n, 3n)
    let t = +s
    let y = CBR(BigRat(1n, 2n), BigRat(-1n, 3n))
    println(+r, " ", +r + +r, " ", - +r, " ", +rat8(1, 2), " ", (+r).typename, " ", (+r).hex)
    println(t, " ", +s + +s, " ", s, " ", (+s).typename, " ", (+y).hex, " ", (+y).real)
    // a number's + is C's still
    let i:u8 = 200
    println(+i, " ", (+i).typename, " ", +1.5, " ", (+1).typename)
    return 0
}
// out: 1n 255n 15n 5n 1n 1n -1n -1n
// out: +0xffn +0xffn +0o377n +0b11111111n true
// out: BigInt 1180591620717411303424n 18446744073709551615n 3n -1n
// out: 6n 5n 5n BigInt 10n -5n -5n
// out: 10n +0x5n 2n 5n
// out: 12n 7n 5n 10n
// out: 1.5 -2.0 c64 (+0x1.8p0-0x1p+1.i) (+1.0+2.0.i)
// out: 9 3 8 2 -3 -3 vec
// out: (1/3) (2/3) (-1/3) (1/2) rat64 (+0x1/0x3)
// out: (1n/3n) (2n/3n) (1n/3n) BigRat ((+0x1n/0x2n)+(-0x1n/0x3n).i) (1n/2n)
// out: 200 i32 1.5 i32
