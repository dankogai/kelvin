// i32 arithmetic is an i32, which fits i64 and f64 alike (#41)
let twice(n:i64):i64 { n * 2 }
let twice(x:f64):f64 { x * 2.0 }
let main():i32 {
    let small:i32 = 3
    println(twice(small + small))
    return 0
}
// error: twice(...) fits more than one of its overloads equally: convert an argument, as in 'x as f64'
