// error: '??' of i64? falls back to an i64, and this is i64?
// a ?? b falls back to the value's type (#251): an Optional on the right
// is no i64, so a chain ends with a value, a ?? b ?? 0
let main():int32 {
    var a:int64? = none
    var b:int64? = 2
    println(a ?? b)
    return 0
}
