// arithmetic of numbers where a function goes is a number (#791), the
// user's answer: kelvinc left it to C, incompatible integer to pointer
// conversion, and kc said this is i64
let take(f:(int64):int64):int64 { return f(1) }

let main():int32 {
    var x:int64 = 1
    println(take(x + 1))
    return 0
}
// error: this is a number, where (i64):i64 goes
