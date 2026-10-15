// a subscript is chosen by the types of its indices (#136)
struct pair { a: i64; b: i64 }
let pair[](i:i32):i64 { self.a }
let pair[](i:i16):i64 { self.b }
let main():i32 {
    var p:pair = {1, 2}
    println(p[0])
    return 0
}
// error: the indices fit more than one subscript of pair: write their types
