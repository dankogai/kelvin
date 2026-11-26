// -q of an Optional (#769), which was C's error of kc's C
let main():int32 {
    var q:int64? = 1
    println(-q)
    return 0
}
// error: no operator - takes i64?: define one, as in 'let -(a:i64?):... { ... }'
