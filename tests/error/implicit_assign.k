// error: an assignment has no value (#26), but this function has a result, of type i64
var g:i64 = 0
setg(x:i64):i64 { g = x }
main():i32 {
    println(setg(5))
    return 0
}
