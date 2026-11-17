// a rational of its text (#565): rat64("8/-12") is (-2/3) and
// BigRat("8/-12") (-2n/3n), so T(text) gives the value back, as
// i64("42") does; with a base it reads .hex, .oct and .bin, whose
// denominator has no sign now: the sign is the numerator's alone
#import <BigNum>
let main():int32 {
    // a sign on either part, in lowest terms; spaces and a ( may come first
    println(rat64("8/-12"), " ", BigRat("8/-12"), " ", rat64("-8/-12"), " ", rat64("(-2/3)"), " ", BigRat("(-2n/3n)"), " ", rat64(" ( 8 / -12 )"))
    // the texts: the denominator has no sign, in any base
    let r = rat64(-2, 3)
    let b = BigRat(-2n, 3n)
    println(r, " ", r.hex, " ", r.oct, " ", r.bin, " ", rat64(2, 3).hex, " ", r.string, " ", r.string.typename)
    println(b, " ", b.hex, " ", b.oct, " ", b.bin, " ", BigRat(2n, 3n).hex)
    // each read back by its type, in its base
    println(rat64(r.hex, 16) == r, " ", rat64(r.oct, 8) == r, " ", rat64(r.bin, 2) == r, " ", rat64(r.cstr) == r, " ", rat64(r.cstr, 10))
    println(BigRat(b.hex, 16) == b, " ", BigRat(b.oct, 8) == b, " ", BigRat(b.bin, 2) == b, " ", BigRat(b.hex, 16))
    // of a String by reference
    let s = $`${r}`
    let t = b.string
    let h = b.hex
    println(rat64(&s), " ", BigRat(&t), " ", BigRat(&h, 16), " ", rat64(&s, 10), " ", rat64(&s) == r, " ", BigRat(&t) == b)
    // no denominator is 1; an infinity, a NaN, and what is no number, a NaN too (#567)
    println(rat64("5"), " ", BigRat("5n"), " ", rat64("1/0"), " ", rat64("-1/0"), " ", rat64("0/0"), " ", rat64("0/5"), " ", rat64("abc"), " ", rat64(""))
    println(rat64("(1/0)").isInfinite, " ", rat64("(0/0)").isNaN, " ", BigRat("(-1n/0n)"), " ", BigRat("(0n/0n)").isNaN)
    // text with no number is an error, a NaN (#567): there is no numerator to read, in any width or base
    println(rat64("abc"), " ", BigRat("abc"), " ", rat8(""), " ", BigRat(""), " ", rat64("("), " ", rat64("  "), " ", rat64("-"), " ", rat64("n"))
    println(rat64("abc").isNaN, " ", BigRat("").isNaN, " ", rat64("abc", 16), " ", rat64("z", 36), " ", rat64("z"), " ", rat64("."), " ", rat64("()"))
    let none = $""
    let word = $"abc"
    println(rat64(&none), " ", BigRat(&word), " ", rat64(&word, 16), " ", rat64("0"), " ", rat64("-0"), " ", rat64("+7"), " ", BigRat("0n"))
    // where a / is written, a part left out is an error, a NaN: the denominator is left out only with its /
    println(rat64("1/"), " ", BigRat("1/"), " ", rat8("(1/)"), " ", rat64("1/x"), " ", rat64("1/-"), " ", BigRat("7/", 16), " ", rat64("1/").isNaN, " ", BigRat("1/").isNaN)
    println(rat64("1"), " ", rat64("1/1"), " ", rat64("1/ 3"), " ", rat64("1/+3"), " ", rat64("1/0x3", 16), " ", rat64("1/z", 36), " ", rat64("1/z"), " ", rat64("1/8", 8))
    println(rat64("/3"), " ", BigRat("/3"), " ", rat8("(/3)"), " ", rat64("x/3"), " ", rat64("-/3"), " ", rat64("/"), " ", rat64("/3").isNaN, " ", BigRat("/3").isNaN)
    println(rat64("0/3"), " ", rat64("-1/3"), " ", rat64(" ( +1 / 3 )"), " ", rat64("f/3", 16), " ", rat64("f/3"))
    // each width, and a NaN where a part does not fit it
    println(rat8("(1/3)"), " ", rat16("6/4"), " ", rat32("-10/4"), " ", rat8("(1/3)").typename, " ", rat16("1/2").typename, " ", rat32("1/2").typename)
    println(rat8("300/7"), " ", rat8("127/-128"), " ", rat8("-128/127"), " ", rat16("-32768/3"), " ", rat8("ff/100", 16), " ", rat8(rat8(1, 3).hex, 16))
    println(rat64("123456789012345678901234567890/10"), " ", rat64("123456789012345678901234567890/246913578024691357802469135780"))
    println(BigRat("123456789012345678901234567890/-10"), " ", BigRat("zz/-z", 36))
    // a number is read as an f64's text is written, and exactly (#568): a point, and in base 10 an exponent
    println(rat64("1.5"), " ", rat64("2.5/1.5"), " ", rat64("0.1"), " ", BigRat("1.5"), " ", BigRat("0.1"), " ", rat64(".5"), " ", rat64("5."), " ", rat64("-0.0"))
    println(rat64("1.5e-3"), " ", rat64("1e3"), " ", rat64("1E3"), " ", rat64("-2.50e+1"), " ", rat64("2.5/-1.5"), " ", rat64("(1.5/2)"), " ", rat64("1/0.0"), " ", rat64("0.0/0"))
    println(rat64("9007199254740993"), " ", BigRat("123456789012345678901234567890.5"), " ", BigRat("1.5e-30"), " ", rat64("0.3333333333333333333"))
    // a point in any base, and an exponent in base 10 alone: e is a digit of base 16
    println(rat64("1.8", 16), " ", rat64("0x1.8", 16), " ", rat64("1e3", 16), " ", rat64("-0b1.1", 2), " ", rat64("0o1.4", 8), " ", BigRat("ff.8", 16), " ", rat64("1e3", 12))
    // text with more than a number is an error, a NaN (#568): all of it is to be read
    println(rat64("5x"), " ", BigRat("5x"), " ", rat64("1/3x"), " ", rat64("1/2/3"), " ", rat64("1.5.5"), " ", rat64("1e"), " ", rat64("1e+"), " ", rat64("1.5n"))
    println(rat64("(1/3"), " ", rat64("1/3)"), " ", rat64("(1/3))"), " ", rat64("--1"), " ", rat64("+ 1"), " ", rat64("1e 3"), " ", rat64("0x", 16), " ", rat64("5", 99))
    println(rat64(" ( 1 / 3 ) "), " ", rat64("1 /3"), " ", rat64("5 "), " ", BigRat("5n "), " ", rat64("5x").isNaN, " ", BigRat("5x").isNaN)
    // each width, a NaN where a part does not fit it; a power of 10 no width holds is not reckoned
    println(rat8("0.5"), " ", rat8("0.001"), " ", rat16("0.001"), " ", rat8("1e2"), " ", rat8("1e3"), " ", rat32("1.5e-3"), " ", rat64("1e999999999999999999999"), " ", rat64("0e999999999999999999999"))
    println(rat64("1e30/1e30"), " ", rat64("1e-30/1e-30"), " ", rat64("1e400/1e399"), " ", rat64("1e-999999999"), " ", BigRat("1e30"))
    // the constructors of numbers are as they were
    println(rat64(0), " ", rat64(1, 3), " ", rat64(5), " ", BigRat(1), " ", BigRat(1n), " ", BigRat(1, 3), " ", rat64(rat8(1, 2)))
    // an infinity's and a NaN's .hex, and a CBR's, of two BigRats
    println(rat64(1, 0).hex, " ", rat64(0, 0).hex, " ", BigRat(-1, 0).hex, " ", CBR(BigRat(1n, 2n), BigRat(-1n, 3n)).hex)
    return 0
}
// out: (-2/3) (-2n/3n) (2/3) (-2/3) (-2n/3n) (-2/3)
// out: (-2/3) (-0x2/0x3) (-0o2/0o3) (-0b10/0b11) (+0x2/0x3) (-2/3) String
// out: (-2n/3n) (-0x2n/0x3n) (-0o2n/0o3n) (-0b10n/0b11n) (+0x2n/0x3n)
// out: true true true true (-2/3)
// out: true true true (-2n/3n)
// out: (-2/3) (-2n/3n) (-2n/3n) (-2/3) true true
// out: (5/1) (5n/1n) (1/0) (-1/0) (0/0) (0/1) (0/0) (0/0)
// out: true true (-1n/0n) true
// out: (0/0) (0n/0n) (0/0) (0n/0n) (0/0) (0/0) (0/0) (0/0)
// out: true true (2748/1) (35/1) (0/0) (0/0) (0/0)
// out: (0/0) (0n/0n) (2748/1) (0/1) (0/1) (7/1) (0n/1n)
// out: (0/0) (0n/0n) (0/0) (0/0) (0/0) (0n/0n) true true
// out: (1/1) (1/1) (1/3) (1/3) (1/3) (1/35) (0/0) (0/0)
// out: (0/0) (0n/0n) (0/0) (0/0) (0/0) (0/0) true true
// out: (0/1) (-1/3) (1/3) (5/1) (0/0)
// out: (1/3) (3/2) (-5/2) rat8 rat16 rat32
// out: (0/0) (0/0) (-128/127) (-32768/3) (0/0) (1/3)
// out: (0/0) (1/2)
// out: (-12345678901234567890123456789n/1n) (-37n/1n)
// out: (3/2) (5/3) (1/10) (3n/2n) (1n/10n) (1/2) (5/1) (0/1)
// out: (3/2000) (1000/1) (1000/1) (-25/1) (-5/3) (3/4) (1/0) (0/0)
// out: (9007199254740993/1) (246913578024691357802469135781n/2n) (3n/2000000000000000000000000000000n) (0/0)
// out: (3/2) (3/2) (483/1) (-3/2) (3/2) (511n/2n) (0/0)
// out: (0/0) (0n/0n) (0/0) (0/0) (0/0) (0/0) (0/0) (0/0)
// out: (0/0) (0/0) (0/0) (0/0) (0/0) (0/0) (0/0) (0/0)
// out: (1/3) (1/3) (5/1) (5n/1n) true true
// out: (1/2) (0/0) (1/1000) (100/1) (0/0) (3/2000) (0/0) (0/1)
// out: (1/1) (1/1) (10/1) (0/0) (1000000000000000000000000000000n/1n)
// out: (0/1) (1/3) (5/1) (1n/1n) (1n/1n) (1n/3n) (1/2)
// out: (+0x1/0x0) (+0x0/0x0) (-0x1n/0x0n) ((+0x1n/0x2n)+(-0x1n/0x3n).i)
