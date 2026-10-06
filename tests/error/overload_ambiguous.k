// an i32 converts to an i64 and to an f64 alike (#41)
let twice(n:i64):i64 { n * 2 }
let twice(x:f64):f64 { x * 2.0 }
let main():i32 {
    let n:i32 = 3
    println(twice(n))
    return 0
}
// error: twice(...) fits more than one of its overloads equally: convert an argument, as in 'x as f64'
