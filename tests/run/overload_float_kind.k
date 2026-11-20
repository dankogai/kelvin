// a float prefers a float's parameter, and an integer an integer's (Q14,
// #632): an f32 the f64's, a u8 the i64's, and literals of each kind
let half(n:i64):i64 { n / 2 }
let half(x:f64):f64 { x / 2.0 }
let main():int32 {
    let x:f32 = 3.0
    let b:u8 = 9
    println(half(x), " ", half(b), " ", half(7), " ", half(7.0))
    return 0
}
// out: 1.5 4 3 3.5
