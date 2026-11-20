// a variable of a function type is called, also where it is named as a
// function it hides (#620)
let half(x:f64):f64 { return x / 2.0 }
let main():int32 {
    let sqrt:(f64):f64 := half
    println(sqrt(3.0), " ", Kelvin.sqrt(4.0))
    return 0
}
// out: 1.5 2.0
