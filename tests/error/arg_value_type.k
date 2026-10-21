// error: 'x' of 'half' is an f64, and this is text
let half(x:float64):float64 { x / 2 }

let main():int32 {
    println(half("ten"))
    return 0
}
