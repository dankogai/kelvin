// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
let area(w:int64, h:int64):int64 {
    let unused:int64 = 1
    w * h
}
let main():int32 {
    println(area(2, 3))
    return 0
}
