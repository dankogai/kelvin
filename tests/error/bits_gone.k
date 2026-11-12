// Bits is no more (#532): an integer's bits are x.bits (#530) and a
// BigInt's b.bits (#531), each an Array<bool>, and Bits(...) says so
let main():int32 {
    var bv = Bits(u8(0))
    bv[0] = true
    return 0
}
// error: Bits is no more (#532): an integer's bits are x.bits, an Array<bool>, and x.bits[n] its bit n; a BigInt's are b.bits, of any width; and bools that grow are an Array<bool>
