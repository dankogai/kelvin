// a let attribute reads self and never changes it (#137)
struct counter { n: int64 }
let counter.next:int64 {
    .n += 1
    return .n
}
let main():int32 { return 0 }
// error: a let attribute and a var attribute's getter read self and never change it
