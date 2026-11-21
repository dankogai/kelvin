// error: malformed number '1e_5': a '_' separates digits and follows one, as in 1_000 or 0xff_ff
// an exponent's digits begin with a digit (#671)
let main():int32 {
    let x = 1e_5
    println(x)
    return 0
}
