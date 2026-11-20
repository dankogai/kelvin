// so of a method's overloads (#158): an integer argument prefers the
// integer's parameter (Q14, #632), where it was an error
struct box { v: int64 }
extend box {
    let add(n:int64):int64 { .v + n }
    let add(x:float64):int64 { .v + x as int64 }
}
let main():int32 {
    var b:box = {.v = 1}
    var k:int32 = 2
    println(b.add(k))
    return 0
}
// out: 3
