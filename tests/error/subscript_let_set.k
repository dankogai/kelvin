// a let subscript is read and never set (#136)
struct pair { a: int64; b: int64 }
let pair[](i:int64):int64 { i == 0 ? .a : .b }
let main():int32 {
    var p:pair = {1, 2}
    p[0] = 3
    return 0
}
// error: this subscript of pair is a let, read and never set: a var subscript has a setter
