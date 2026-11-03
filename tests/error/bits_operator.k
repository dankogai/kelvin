// a Bits has the bitwise operators alone: its u64s are .u64s (#387, #455)
let main():int32 {
    let bv = Bits(3)
    println(bv + bv)
    return 0
}
// error: a Bits has '|', '&', '~', '<<', '>>', '==' and '!=', and no '+': its u64s are '.u64s'
