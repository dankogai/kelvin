// a subscript is chosen by the count of its indices (#136)
struct pair { a: int64; b: int64 }
let pair[](i:int64):int64 { .a }
let main():int32 {
    var p:pair = {1, 2}
    println(p[0, 1])
    return 0
}
// error: no subscript of pair takes 2 indices
