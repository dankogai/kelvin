// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
let compute(y:int64):int64 { y * 2 }
let next(x:int64):int64 {
    let y:int64 = x + 1
    compute(y)
}
let main():int32 {
    println(next(1))
    return 0
}
