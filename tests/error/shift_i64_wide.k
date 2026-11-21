// an i64 shifted by 64 or more (#665)
let main():int32 {
    var x:i64 = 5
    println(x << 64)
    return 0
}
// error: '<< 64' shifts an i64 by 64, its width or more, which C leaves undefined
