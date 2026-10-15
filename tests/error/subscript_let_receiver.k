// a subscript is set on the var that holds the value (#136)
struct pair { a: i64; b: i64 }
var pair[](i:i64):i64 {
    get { i == 0 ? self.a : self.b }
    set(v) { if i == 0 { self.a = v } else { self.b = v } }
}
let main():i32 {
    let p:pair = {1, 2}
    p[0] = 3
    return 0
}
// error: 'p' is a let and cannot change; declare it with var
