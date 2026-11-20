// a number prefers a parameter of its own kind (Q14, #632), and where
// one overload is so for an argument and another for the next, neither
// is nearer: convert one
let pair(a:i64, b:i64):i64 { a + b }
let pair(a:f64, b:f64):f64 { a + b }
let main():int32 {
    let n:i32 = 1
    let x:f32 = 2.0
    println(pair(n, x))
    return 0
}
// error: pair(...) fits more than one of its overloads equally: convert an argument, as in 'x as f64'
