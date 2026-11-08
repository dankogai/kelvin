// uchr(x) takes an integer, a uchr or text, as '.uchr' does (#297): a
// float, sum or no, is a Kelvin error, where it was C's (#494)
let main():int32 {
    let x:float64 = 65.5
    println(uchr(x + 1))
    return 0
}
// error: uchr(x) takes an integer, a uchr or text, and this is f64: convert it to an integer first, uchr(i64(x))
