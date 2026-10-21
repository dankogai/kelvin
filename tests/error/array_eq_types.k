// error: '==' compares two Arrays of the same element type, and these are Array<i64> and Array<f64>
let main():int32 {
    var a = $[1, 2]
    var b = $[1.0, 2.0]
    println(a == b)
    return 0
}
