// b.bits is a copy of b's bits (#531): it is not set whole
let main():int32 {
    var b = 5n
    b.bits = $[true]
    return 0
}
// error: a BigInt's '.bits' is a copy of its bits, an Array<bool>: a bit is set with 'b.bits[n] = v', and all of them with 'b = BigInt(bools)'
