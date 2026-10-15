// a slice is no subscript (#136)
struct pair { a: i64; b: i64 }
let pair[](i:i64):i64 { self.a }
let main():i32 {
    var p:pair = {1, 2}
    println(p[0..<1])
    return 0
}
// error: a slice is no subscript of pair
