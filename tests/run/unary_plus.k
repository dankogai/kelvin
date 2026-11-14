// +x, the prefix (#560, kc's; kelvinc read it): C's, the value itself,
// a small integer's an int as -x's is; +1 is the number 1, which fits
// what 1 fits; a text with a sign pastes back, a float's .dec and .hex
// (#558) and a complex number's (#559)
#import <math>
let main():int32 {
    var b:u8 = 200
    var h:i16 = -3
    var f:f32 = 1.5
    var u:u64 = 7
    // a variable's: the value, and a small integer's type is int32
    println(+b, " ", +h, " ", +f, " ", +u, " ", (+b).typename, " ", (+h).typename, " ", (+f).typename, " ", (+u).typename)
    println((+b).size, " ", sizeof(+b), " ", +b as i64, " ", (+f).hex, " ", +f:f64, " ", +(b + 1), " ", +h * 2)
    // a literal's: the number, an i32, an f64, and whatever is declared
    let k:u8 = +200
    let m:i8 = +127
    let d:f64 = +2
    let e:f32 = +1.5
    var x = +1
    var y = +1.5
    println(k, " ", m, " ", d, " ", e, " ", x.typename, " ", y.typename, " ", (+1).typename, " ", (+1.5).typename)
    println(+0x10, " ", +1e3, " ", +i64.max, " ", +i64.min, " ", +0.0, " ", -0.0, " ", +18446744073709551615)
    // among the other prefixes, and after a binary operator
    println(+-+1, " ", - +1, " ", -+-h, " ", 1 + +2, " ", 1 - +2, " ", +b + +h, " ", !(+h == 3), " ", ~+b)
    // ** binds tighter than a prefix on its left, and takes one on its right
    println((+2) ** 3, " ", +2 ** 3, " ", 2 ** +3, " ", 2.0 ** +0.5, " ", +2.0 ** 2.0)
    // in an array, an index, a range, a switch, a ?: and a template
    let a:[i32](3) = [+1, -2, +3]
    let r:Range<i32> = +1...+3
    println(a[+1], " ", a[1 + +1], " ", r, " ", +1..<+3, " ", h > +0 ? +1 : -1, " ", `${+h} ${+1.5}`)
    switch +h {
    case -3: println("minus three")
    default: println("other")
    }
    // a line that begins with + goes on with the line before it, as with -
    let t:i32 = 10
        + 5
    println(t)
    // the texts with a sign paste back
    let z = c64(1.5, -2.0)
    println(+2.0, " ", +0x1.8p+0, " ", +0.10000000000000001 == 0.1, " ", (+0x1.8p+0-0x1p+1.i) == z, " ", (+1.5-2.0.i) == z, " ", (+1.5+2.0.i))
    println(+42 == 42, " ", +0x2a, " ", +0b101010, " ", -0x2a)
    return 0
}
// out: 200 -3 1.5 7 i32 i32 f32 u64
// out: 4 4 200 +0x1.8p+0 1.5 201 -6
// out: 200 127 2.0 1.5 i64 f64 i32 f64
// out: 16 1000.0 9223372036854775807 -9223372036854775808 0.0 -0.0 18446744073709551615
// out: -1 -1 -3 3 -1 197 true -201
// out: 8 8 8 1.4142135623730951 4.0
// out: -2 3 1...3 1..<3 -1 -3 1.5
// out: minus three
// out: 15
// out: 2.0 1.5 true true true {real: 1.5, imag: 2.0}
// out: true 42 42 -42
