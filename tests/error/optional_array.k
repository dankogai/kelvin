// an Optional holds a value, not an array (#72)
let main():int32 {
    var z:[int64](3)? = none
    return 0
}
// error: an Optional holds a value, and an array is none: hold an Array, $[i64]
