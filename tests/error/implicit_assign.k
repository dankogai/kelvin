// error: an assignment has no value (#26), but this function has a result, of type i64
var g:int64 = 0
let setg(x:int64):int64 { g = x }
let main():int32 {
    println(setg(5))
    return 0
}
