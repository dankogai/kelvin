// a variable of a function type is assigned one of its type (#748), a
// variable's of another type too
let twice(x:int64):int64 { x * 2 }
let half(x:float64):int64 { 1 }
let main():int32 {
    var g:(int64):int64 := twice
    var h:(float64):int64 := half
    g := h
    return 0
}
// error: this is (f64):i64, where (i64):i64 goes
