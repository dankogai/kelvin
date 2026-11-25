// an element of a function type is a function of that type (#748,
// #752), said as any element's
let main():int32 {
    var fs:[(int64):int64](1) = [{ (x:float64):int64 in 2 }]
    return 0
}
// error: an element of [(i64):i64](1) is a (i64):i64, and this is (f64):i64
