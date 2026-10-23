// '.uchr' converts an integer (#56): a float sum is a number, but none,
// an error where it went to C as a struct's member (#297)
let main():int32 {
    let x:float64 = 1.5
    println((x + 1.5).uchr)
    return 0
}
// error: '.uchr' converts an integer to a codepoint, and this is f64
