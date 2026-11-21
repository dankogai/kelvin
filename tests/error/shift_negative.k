// a shift by a negative count (#665)
let main():int32 {
    var x:i64 = 5
    println(x >> -1)
    return 0
}
// error: '>> -1' shifts by a negative count, which C leaves undefined
