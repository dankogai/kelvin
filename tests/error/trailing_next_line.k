// error: a trailing function starts on the line of the call's ')': on the next line, '{' starts a block
var total:int64 = 0
let each(n:int64, f:(int64)) {
    for i in 0..<n {
        f(i)
    }
}
let main():int32 {
    each(3)
    {
        total += $0
    }
    return 0
}
