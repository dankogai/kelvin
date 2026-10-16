// a subscript is set on the var that holds the value (#136)
struct pair { a: int64; b: int64 }
var pair[](i:int64):int64 {
    get { i == 0 ? .a : .b }
    set(v) { if i == 0 { .a = v } else { .b = v } }
}
let main():int32 {
    let p:pair = {1, 2}
    p[0] = 3
    return 0
}
// error: 'p' is a let and cannot change; declare it with var
