// a Bits has the bitwise operators alone: its u64 is .value (#387)
let main():int32 {
    let bv = Bits(3)
    println(bv + bv)
    return 0
}
// error: a Bits has '|', '&', '~', '<<', '>>', '==' and '!=', and no '+': its u64 is '.value'
