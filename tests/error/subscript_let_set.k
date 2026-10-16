// a let subscript is read and never set (#136)
struct pair { a: i64; b: i64 }
let pair[](i:i64):i64 { i == 0 ? .a : .b }
let main():i32 {
    var p:pair = {1, 2}
    p[0] = 3
    return 0
}
// error: this subscript of pair is a let, read and never set: a var subscript has a setter
