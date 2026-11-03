// a Bits is made of bools, [bool]s, integers and text (#455)
let main():int32 {
    let bv = Bits(1.5)
    println(bv)
    return 0
}
// error: Bits(x, ...) takes bools, [bool]s, integers and text "0b...", and this is f64
