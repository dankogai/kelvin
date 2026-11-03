// a Bits holds u64s and grows past 64 bits (#455): its .value is gone
let main():int32 {
    let bv = Bits(3)
    println(bv.value)
    return 0
}
// error: a Bits holds u64s, '.u64s', and grows past 64 bits (#455): '.value' is gone
