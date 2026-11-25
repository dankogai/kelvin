// a function returned is of the result's function type (#748)
let pick():(int64):int64 {
    return { (x:float64):int64 in 2 }
}
let main():int32 {
    println(pick()(1))
    return 0
}
// error: this is (f64):i64, where (i64):i64 goes
