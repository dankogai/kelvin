// a getter reads self and never changes it (#136)
struct pair { a: int64; b: int64 }
let pair[](i:int64):int64 {
    .a = i
    return .a
}
let main():int32 { return 0 }
// error: a let subscript and a var subscript's getter read self and never change it
