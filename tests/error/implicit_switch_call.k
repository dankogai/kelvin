// error: this value would be dropped: a body returns its value without 'return' only when it is one expression
let twice(x:int64):int64 { x * 2 }
let pick(n:int64):int64 {
    switch (n) {
    case 0:
        return 0
    default:
        twice(n)
    }
}
let main():int32 {
    println(pick(1))
    return 0
}
