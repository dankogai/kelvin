// a number appended to an Array of functions is said as an element's
// (#757), where kc said this is i64, where (i64):i64 goes
let twice(x:int64):int64 { x * 2 }
let main():int32 {
    var fs:$[(int64):int64] = $[twice]
    fs += 5
    return 0
}
// error: an element of Array<(i64):i64> is a (i64):i64, and this is a number
