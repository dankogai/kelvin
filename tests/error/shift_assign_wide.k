// of x <<= n too (#665)
let main():int32 {
    var x:i32 = 5
    x >>= 32
    println(x)
    return 0
}
// error: '>>= 32' shifts an i32 by 32, its width or more, which C leaves undefined
