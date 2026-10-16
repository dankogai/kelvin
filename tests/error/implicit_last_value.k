// error: a body returns its value without 'return' only when it is one expression
let dbl(x:int64):int64 {
    let y:int64 = x * 2
    y
}
let main():int32 {
    println(dbl(21))
    return 0
}
