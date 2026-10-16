// an owner that an expression gives is bound before its subscript (#136)
struct bag { d: Dictionary<String, int64> }
let bag[](k:cstr):i64 { 0 }
let make():bag { return {${:}} }
let main():i32 {
    println(make()["k"])
    return 0
}
// error: a subscript of bag that an expression gives, which nothing would free: bind it to a variable first
