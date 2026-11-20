// an i32 converts to an i64 and to an f64, and prefers the i64, a
// parameter of its own kind (Q14, #632), where it was an error (#41)
let twice(n:int64):int64 { n * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    let n:int32 = 3
    println(twice(n))
    return 0
}
// out: 6
