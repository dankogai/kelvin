// error: malformed number '0_x10': a '_' separates digits and follows one, as in 1_000 or 0xff_ff
// 0x is written as it is (#671): 0_x10 is no hex number with a _ in it
let main():int32 {
    let x = 0_x10
    println(x)
    return 0
}
