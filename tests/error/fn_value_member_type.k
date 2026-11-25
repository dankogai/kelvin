// a struct's member of a function type takes a function of that type
// (#748), as a parameter does
struct ops { f:(int64):int64, n:int64 }
let main():int32 {
    var o:ops = {{ (x:float64):int64 in 2 }, 1}
    return 0
}
// error: this is (f64):i64, where (i64):i64 goes
