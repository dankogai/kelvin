// map's function takes the value (#80)
let half(x:float64):float64 { return x / 2.0 }
let main():int32 {
    var a:int64? = 3
    var m = a.map(half)
    return 0
}
// error: '.map' calls its function with the some, i64, and this takes f64
