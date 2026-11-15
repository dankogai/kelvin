// a rational of its text (#565): rat64("8/-12") is (-2/3) and
// bigrat("8/-12") (-2n/3n), so T(text) gives the value back, as
// i64("42") does; with a base it reads .hex, .oct and .bin, whose
// denominator has no sign now: the sign is the numerator's alone
#import <Rational>
#import <math>
let main():int32 {
    // a sign on either part, in lowest terms; spaces and a ( may come first
    println(rat64("8/-12"), " ", bigrat("8/-12"), " ", rat64("-8/-12"), " ", rat64("(-2/3)"), " ", bigrat("(-2n/3n)"), " ", rat64(" ( 8 / -12 )"))
    // the texts: the denominator has no sign, in any base
    let r = rat64(-2, 3)
    let b = bigrat(-2n, 3n)
    println(r, " ", r.hex, " ", r.oct, " ", r.bin, " ", rat64(2, 3).hex, " ", r.string, " ", r.string.typename)
    println(b, " ", b.hex, " ", b.oct, " ", b.bin, " ", bigrat(2n, 3n).hex)
    // each read back by its type, in its base
    println(rat64(r.hex, 16) == r, " ", rat64(r.oct, 8) == r, " ", rat64(r.bin, 2) == r, " ", rat64(r.cstr) == r, " ", rat64(r.cstr, 10))
    println(bigrat(b.hex, 16) == b, " ", bigrat(b.oct, 8) == b, " ", bigrat(b.bin, 2) == b, " ", bigrat(b.hex, 16))
    // of a String by reference
    let s = $`${r}`
    let t = b.string
    let h = b.hex
    println(rat64(&s), " ", bigrat(&t), " ", bigrat(&h, 16), " ", rat64(&s, 10), " ", rat64(&s) == r, " ", bigrat(&t) == b)
    // no denominator is 1; an infinity, a NaN, and what is no number
    println(rat64("5"), " ", bigrat("5n"), " ", rat64("1/0"), " ", rat64("-1/0"), " ", rat64("0/0"), " ", rat64("0/5"), " ", rat64("abc"), " ", rat64(""))
    println(rat64("(1/0)").isInfinite, " ", rat64("(0/0)").isNaN, " ", bigrat("(-1n/0n)"), " ", bigrat("(0n/0n)").isNaN)
    // where a / is written, a part left out is an error, a NaN: the denominator is left out only with its /
    println(rat64("1/"), " ", bigrat("1/"), " ", rat8("(1/)"), " ", rat64("1/x"), " ", rat64("1/-"), " ", bigrat("7/", 16), " ", rat64("1/").isNaN, " ", bigrat("1/").isNaN)
    println(rat64("1"), " ", rat64("1/1"), " ", rat64("1/ 3"), " ", rat64("1/+3"), " ", rat64("1/0x3", 16), " ", rat64("1/z", 36), " ", rat64("1/z"), " ", rat64("1/8", 8))
    println(rat64("/3"), " ", bigrat("/3"), " ", rat8("(/3)"), " ", rat64("x/3"), " ", rat64("-/3"), " ", rat64("/"), " ", rat64("/3").isNaN, " ", bigrat("/3").isNaN)
    println(rat64("0/3"), " ", rat64("-1/3"), " ", rat64(" ( +1 / 3 )"), " ", rat64("f/3", 16), " ", rat64("f/3"))
    // each width, and a NaN where a part does not fit it
    println(rat8("(1/3)"), " ", rat16("6/4"), " ", rat32("-10/4"), " ", rat8("(1/3)").typename, " ", rat16("1/2").typename, " ", rat32("1/2").typename)
    println(rat8("300/7"), " ", rat8("127/-128"), " ", rat8("-128/127"), " ", rat16("-32768/3"), " ", rat8("ff/100", 16), " ", rat8(rat8(1, 3).hex, 16))
    println(rat64("123456789012345678901234567890/10"), " ", rat64("123456789012345678901234567890/246913578024691357802469135780"))
    println(bigrat("123456789012345678901234567890/-10"), " ", bigrat("zz/-z", 36))
    // the constructors of numbers are as they were
    println(rat64(0), " ", rat64(1, 3), " ", rat64(5), " ", bigrat(1), " ", bigrat(1n), " ", bigrat(1, 3), " ", rat64(rat8(1, 2)))
    // an infinity's and a NaN's .hex, and a cbr's, of two bigrats
    println(rat64(1, 0).hex, " ", rat64(0, 0).hex, " ", bigrat(-1, 0).hex, " ", cbr(bigrat(1n, 2n), bigrat(-1n, 3n)).hex)
    return 0
}
// out: (-2/3) (-2n/3n) (2/3) (-2/3) (-2n/3n) (-2/3)
// out: (-2/3) (-0x2/0x3) (-0o2/0o3) (-0b10/0b11) (+0x2/0x3) (-2/3) String
// out: (-2n/3n) (-0x2n/0x3n) (-0o2n/0o3n) (-0b10n/0b11n) (+0x2n/0x3n)
// out: true true true true (-2/3)
// out: true true true (-2n/3n)
// out: (-2/3) (-2n/3n) (-2n/3n) (-2/3) true true
// out: (5/1) (5n/1n) (1/0) (-1/0) (0/0) (0/1) (0/1) (0/1)
// out: true true (-1n/0n) true
// out: (0/0) (0n/0n) (0/0) (0/0) (0/0) (0n/0n) true true
// out: (1/1) (1/1) (1/3) (1/3) (1/3) (1/35) (0/0) (0/0)
// out: (0/0) (0n/0n) (0/0) (0/0) (0/0) (0/0) true true
// out: (0/1) (-1/3) (1/3) (5/1) (0/0)
// out: (1/3) (3/2) (-5/2) rat8 rat16 rat32
// out: (0/0) (0/0) (-128/127) (-32768/3) (0/0) (1/3)
// out: (0/0) (1/2)
// out: (-12345678901234567890123456789n/1n) (-37n/1n)
// out: (0/1) (1/3) (5/1) (1n/1n) (1n/1n) (1n/3n) (1/2)
// out: (+0x1/0x0) (+0x0/0x0) (-0x1n/0x0n) ((+0x1n/0x2n)+(-0x1n/0x3n).i)
