// map's function takes the value (#80)
let half(x:f64):f64 { return x / 2.0 }
let main():i32 {
    var a:int64? = 3
    var m = a.map(half)
    return 0
}
// error: '.map' calls its function with the some, i64, and this takes f64
