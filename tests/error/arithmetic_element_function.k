// arithmetic added to an Array of functions is a number (#791): C's
// error in kelvinc, and i64 in kc
let main():int32 {
    var x:int64 = 1
    var a:$[(int64):int64] = $[]
    a += x + 1
    return 0
}
// error: an element of Array<(i64):i64> is a (i64):i64, and this is a number
