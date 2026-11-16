// the else arm of c ? a : b may begin with a type's attribute (#578):
// c ? -f64.infinity : f64.infinity, which kelvinc refused, "expected ':',
// found '.'", the : and f64 read as an annotation of the first arm,
// -f64.infinity:f64; a . after the type's word says it is no annotation
// there, as a ( and a < do (#35, #116). So of every number type's
// attributes, of a method of one, in a case's body, and nested; an
// annotation in an arm is read as it was, c ? 1:i8 : 2:i8
struct limits {
    low: i64
}
extend limits {
    static let top:i64 = 99
}
let pick(c:bool):f64 { c ? -f64.infinity : f64.infinity }
let edge(n:i64):i64 {
    switch n {
    case 0: return i64.max
    case 1: return n > 0 ? n : i64.min
    default: return 0
    }
}
let main():int32 {
    let yes = true
    let no = false
    let a:f64 = yes ? -f64.infinity : f64.infinity
    let b:f64 = no ? -f64.infinity : f64.infinity
    println(a, " ", b, " ", pick(true), " ", pick(false), " ", no ? 1.0 : f64.nan, " ", yes ? 0.5 : f64.pi)
    let x:i64 = 7
    println(no ? x : i64.max, " ", yes ? x : i64.max, " ", no ? 1 : i64.min, " ", no ? 0:u8 : u8.max, " ", no ? x : i32.max as i64, " ", no ? 1:i8 : i8.min)
    // an annotation in an arm is one still, and a value made by a type's word
    println(yes ? 1:i8 : 2:i8, " ", no ? 1:i8 : 2:i8, " ", (no ? 1:i8 : 2:i8).typename, " ", no ? x : i64(2.5), " ", no ? 1.5 : f64("2.5"), " ", (yes ? x:f64 : 0.0).typename)
    // nested, and with what follows the attribute
    println(no ? 1.0 : yes ? f64.infinity : f64.nan, " ", no ? 1.0 : no ? 2.0 : -f64.infinity, " ", no ? 0.0 : f64.pi * 2.0, " ", no ? x : i64.max - 1, " ", no ? x : limits.top, " ", edge(0) == i64.max, " ", edge(1))
    return 0
}
// out: -inf inf -inf inf nan 0.5
// out: 9223372036854775807 7 -9223372036854775808 255 2147483647 -128
// out: 1 2 i8 2 2.5 f64
// out: inf -inf 6.2831853071795862 9223372036854775806 99 true 1
