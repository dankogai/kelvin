// so of the remainder by zero (#662)
let main():int32 {
    var n:i64 = 7
    println(n % 0)
    return 0
}
// error: '% 0' divides an integer by zero, which has no value: C leaves it undefined
