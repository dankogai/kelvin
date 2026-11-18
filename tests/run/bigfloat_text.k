// the text of a BigFloat (#577), with <BigNum>: print writes the
// fewest digits that BigFloat(text) reads back as it, at
// BigFloat.precision bits, so BigFloat("0.1") is 0.1 and a third 39
// digits; laid out as an f64's, plain from 0.0001 up to 2^precision and
// with an exponent otherwise. It is x.string, a String, so a template and
// x.cstr give it; x.dec is the same with a sign, and x.hex C's %a with a
// sign, its value exactly. BigFloat(text) reads a decimal, what else a
// BigRat is read from, a hex float, inf and nan: all of the text, and
// text that is none is a NaN
#import <BigNum>
struct probe {
    name: cstr
    x: BigFloat
}
let main():int32 {
    let tenth = BigFloat("0.1")
    let third = BigFloat(1) / 3
    println(tenth, " ", third, " ", BigFloat(1), " ", BigFloat(-2.5), " ", BigFloat(0), " ", BigFloat(100), " ", BigFloat(0.1))
    println(tenth.string.typename, " ", `${tenth}|${third.round(8)}`, " ", tenth.cstr, " ", tenth * 3, " ", tenth + BigFloat("0.2"), " ", BigFloat("0.3"))
    // it reads back
    println(BigFloat(third.string) == third, " ", BigFloat(third.cstr) == third, " ", BigFloat(third.hex) == third, " ", BigFloat(third.dec) == third, " ", BigFloat(tenth.string) == tenth, " ", tenth == BigFloat(1n.over(10n)))
    // plain from 0.0001 up to 2^128, and with an exponent otherwise
    println(BigFloat("0.0001"), " ", BigFloat("0.00001234"), " ", BigFloat("1e-5"), " ", BigFloat("123456.789"), " ", BigFloat("1e20"), " ", BigFloat("1e40"), " ", BigFloat("-1.5e-300"), " ", BigFloat("1e+1000"))
    let two = BigInt(1) << 128
    println(BigFloat(two), " ", BigFloat(two * 2), " ", BigFloat(two - 1), " ", BigFloat(BigInt(1) << 100))
    // a sign, and the hex float: the bits after the first, and its power of 2
    println(tenth.dec, " ", (-tenth).dec, " ", BigFloat(0).dec, " ", BigFloat(1.5).hex, " ", BigFloat(-0.1).hex, " ", BigFloat(1).hex, " ", BigFloat(1024).hex, " ", BigFloat(0).hex)
    println(third.hex, " ", tenth.hex, " ", BigFloat(5).hex, " ", (BigFloat(1) / 1024).hex, " ", BigFloat(255).hex)
    // infinities and a NaN
    let inf = BigFloat(1) / 0
    println(inf, " ", -inf, " ", inf - inf, " ", inf.dec, " ", (-inf).dec, " ", (inf - inf).dec, " ", inf.hex, " ", (-inf).hex)
    println((inf - inf).hex, " ", BigFloat("inf"), " ", BigFloat("+inf"), " ", BigFloat("-inf"), " ", BigFloat("nan"), " ", BigFloat(inf.hex) == inf, " ", BigFloat((-inf).string) == -inf, " ", BigFloat("1/0"))
    // of text: a decimal, a fraction, a hex float; blanks at its ends
    println(BigFloat("1.5"), " ", BigFloat("-.5"), " ", BigFloat("2."), " ", BigFloat("1.5e3"), " ", BigFloat("15E-1"), " ", BigFloat(" 1.5 "), " ", BigFloat("1/3") == third, " ", BigFloat("(1n/4n)"))
    println(BigFloat("0x1.8p+1"), " ", BigFloat("-0x10"), " ", BigFloat("0x.8"), " ", BigFloat("0X1P-3"), " ", BigFloat("+0x1.999999999999ap-4") == BigFloat(0.1), " ", BigFloat(" 0x1p4 "))
    // text that is none is a NaN
    println(BigFloat("abc"), " ", BigFloat(""), " ", BigFloat("1.5x"), " ", BigFloat("0x"), " ", BigFloat("0x1p"), " ", BigFloat("infinity"), " ", BigFloat("1e"), " ", BigFloat("0x1.8 p1"))
    // to a precision, and by a String
    let s = $"0.1"
    println(BigFloat("0.1", 4), " ", BigFloat("0.1", 4).hex, " ", BigFloat(&s) == tenth, " ", BigFloat(&s, 53) == BigFloat(0.1), " ", BigFloat("0x1.ffp0", 4), " ", BigFloat("1/3", 8))
    // the fewest digits are of the precision: an f64's value at 53 bits is its shortest text
    BigFloat.precision = 53
    println(BigFloat(0.1), " ", BigFloat(1) / 3, " ", BigFloat("0.1") == BigFloat(0.1), " ", BigFloat(1.0e22), " ", BigFloat(9007199254740992.0), " ", BigFloat(5.0e-324), " ", BigFloat(1.7976931348623157e308))
    BigFloat.precision = 8
    println(BigFloat(1) / 3, " ", BigFloat("0.1"), " ", BigFloat(255), " ", BigFloat(256), " ", BigFloat(257), " ", BigFloat(1000000))
    println(third, " ", BigFloat(third.string, 128) == third)             // one of more bits than the precision: at its own
    BigFloat.precision = 128
    // in a struct, an Array and an Optional
    let p:probe = {"t", tenth.copy()}
    let xs = $[BigFloat(1.5), BigFloat("0.1"), BigFloat(1) / 0]
    let o:BigFloat? = BigFloat(2.5)
    println(p, " ", xs, " ", o)
    return 0
}
// out: 0.1 0.333333333333333333333333333333333333334 1.0 -2.5 0.0 100.0 0.100000000000000005551115123125782702118
// out: String 0.1|0.333984375 0.1 0.3 0.3 0.3
// out: true true true true true true
// out: 0.0001 1.234e-05 1e-05 123456.789 100000000000000000000.0 1e+40 -1.5e-300 1e+1000
// out: 340282366920938463463374607431768211456.0 6.80564733841876926926749214863536422912e+38 340282366920938463463374607431768211455.0 1267650600228229401496703205376.0
// out: +0.1 -0.1 +0.0 +0x1.8p0 -0x1.999999999999ap-4 +0x1p0 +0x1p+10 +0x0p0
// out: +0x1.55555555555555555555555555555556p-2 +0x1.9999999999999999999999999999999ap-4 +0x1.4p+2 +0x1p-10 +0x1.fep+7
// out: inf -inf nan +inf -inf nan +inf -inf
// out: nan inf inf -inf nan true true inf
// out: 1.5 -0.5 2.0 1500.0 1.5 1.5 true 0.25
// out: 3.0 -16.0 0.5 0.125 true 16.0
// out: nan nan nan nan nan nan nan nan
// out: 0.1015625 +0x1.ap-4 true true 2.0 0.333984375
// out: 0.1 0.3333333333333333 true 1e+22 9007199254740992.0 4.9406564584124654e-324 1.7976931348623157e+308
// out: 0.334 0.1 255.0 256.0 256.0 1e+06
// out: 0.333333333333333333333333333333333333334 true
// out: {name: "t", x: 0.1} [1.5, 0.1, inf] some(2.5)
