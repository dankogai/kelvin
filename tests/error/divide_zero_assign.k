// and of x /= 0 (#662)
let main():int32 {
    var n:i64 = 7
    n /= 0
    println(n)
    return 0
}
// error: '/= 0' divides an integer by zero, which has no value: C leaves it undefined
