// rat32, rat16 and rat8 (#539): a numerator over a denominator of two
// i32s, i16s and i8s, as rat64 is of two i64s; n.over(d) of a signed
// integer type makes the rational of that type; what does not fit its
// integers is a NaN; two widths do not mix, and rat64(r) and its kin
// convert, a NaN where the narrower does not hold it
#import <Rational>
let main():int32 {
    let n:i8 = 1
    let a = n.over(3)
    let b = rat8(1, 6)
    println(a, " ", b, " ", a + b, " ", a - b, " ", a * b, " ", a / b, " ", -a, " ", a.typename)
    println(a + 1, " ", 2 * a, " ", 1 / a, " ", a == rat8(2, 6), " ", a < b, " ", b < a, " ", a.f64, " ", a.hex)
    println(rat8(1, 15) + rat8(1, 14), " ", rat8(127) + 1, " ", rat8(100) * rat8(2), " ", rat8(1, 0), " ", rat8(-5, 0), " ", rat8(0, 0), " ", -rat8(-128))
    let s:i16 = 355
    let h = s.over(113)
    let m:i32 = 22
    let w = m.over(7)
    println(h, " ", h.typename, " ", h * h, " ", h + h, " ", h.f64)
    println(w, " ", w.typename, " ", w * w * w * w, " ", w.bin)
    println(rat16(1, 200) + rat16(1, 300), " ", rat16(1, 200) * rat16(1, 200), " ", rat32(1, 70000) * rat32(1, 70000), " ", rat32(1, 3) + rat32(1, 6))
    println(rat64(a), " ", rat32(a), " ", rat16(a), " ", rat8(h), " ", rat8(rat64(7, 9)), " ", rat16(rat64(1, 100000)), " ", rat8(w), " ", rat64(w).typename)
    println(rat64(rat8(1, 0)), " ", rat8(rat64(-3, 0)), " ", rat16(rat8(0, 0)), " ", rat64(a) + 1.over(6), " ", rat8(rat64(a) + 1.over(6)))
    println(rat8(0, 0) == rat8(0, 0), " ", rat8(1, 0) > rat8(127), " ", rat16(1, 0).isInfinite, " ", rat32(0, 0).isNaN, " ", rat8(1, 2).isFinite)
    var acc = rat32(0)
    for i:i32 in 1...10 { acc += i.over(i + 1) - (i - 1).over(i) }
    println(acc, " ", $[a, b], " ", `${h} ${w}`, " ", a.cstr, " ", h.oct)
    return 0
}
// out: (1/3) (1/6) (1/2) (1/6) (1/18) (2/1) (-1/3) rat8
// out: (4/3) (2/3) (3/1) true false true 0.33333333333333331 (+0x1/+0x3)
// out: (0/0) (0/0) (0/0) (1/0) (-1/0) (0/0) (0/0)
// out: (355/113) rat16 (0/0) (710/113) 3.1415929203539825
// out: (22/7) rat32 (234256/2401) (+0b10110/+0b111)
// out: (1/120) (0/0) (0/0) (1/2)
// out: (1/3) (1/3) (1/3) (0/0) (7/9) (0/0) (22/7) rat64
// out: (1/0) (-1/0) (0/0) (1/2) (1/2)
// out: false true true true true
// out: (10/11) [(1/3), (1/6)] (355/113) (22/7) (1/3) (+0o543/+0o161)
