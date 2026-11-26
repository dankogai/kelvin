// q -= 1 of an Optional is an operator it has not (#769), which was C's
// error of kc's C
let main():int32 {
    var q:int64? = 1
    q -= 1
    return 0
}
// error: no operator - takes i64? and i64: define one, as in 'let -(a:i64?, b:i64):... { ... }'
