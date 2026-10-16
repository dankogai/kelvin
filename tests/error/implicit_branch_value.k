// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
let sign(x:int64):int64 {
    if x < 0 { -1 } else { 1 }
}
let main():int32 {
    println(sign(-5))
    return 0
}
