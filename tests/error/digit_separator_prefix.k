// error: malformed number '0x_ff': a '_' separates digits and follows one, as in 1_000 or 0xff_ff
// a _ follows a digit (#671), as Swift has it: the digits after 0x begin
// with one
let main():int32 {
    let x = 0x_ff
    println(x)
    return 0
}
