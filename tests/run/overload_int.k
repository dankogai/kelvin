// i32 arithmetic is an i32, which fits i64 and f64: an integer prefers
// the integer's overload (Q14, #632), where it was an error (#41)
let twice(n:int64):int64 { n * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    let small:int32 = 3
    println(twice(small + small))
    return 0
}
// out: 12
