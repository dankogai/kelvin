// error: '!' unwraps an Optional, and this is i64: it is a value already
let main():int32 {
    let n:int64 = 3
    println(n!)
    return 0
}
