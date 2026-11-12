// "2.5".f64 of text and 3.i64 of a number are the converters (#36) where
// a struct has an attribute of that name too, as the prelude's BigInt has
// .f64 and .i64 (#512): the attribute is its struct's alone (#533)
struct money { cents: i64 }
extend money { let u8:u8 { 9 } }
let main():int32 {
    let b = 12n
    let m:money = {250}
    let t := "7"
    println("2.5".f64, " ", "42".i64, " ", 3.i64, " ", 2.5.f64, " ", b.f64, " ", b.i64, " ", t.i64, " ", 300.u8)
    println(m.u8, " ", "200".u8, " ", (1 + 2).f64, " ", `4${2}`.i64, " ", true.i64)
    return 0
}
// out: 2.5 42 3 2.5 12.0 12 7 255
// out: 9 200 3.0 42 1
