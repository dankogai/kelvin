// a subscript is chosen by the types of its indices (#136)
struct pair { a: int64; b: int64 }
let pair[](i:int32):int64 { .a }
let pair[](i:int16):int64 { .b }
let main():int32 {
    var p:pair = {1, 2}
    println(p[0])
    return 0
}
// error: the indices fit more than one subscript of pair: write their types
