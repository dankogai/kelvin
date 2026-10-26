// | of a Bits takes another Bits (#387)
let main():int32 {
    let bv = Bits(3)
    println(bv | 1)
    return 0
}
// error: '|' of a Bits takes another Bits: 'Bits(n)' makes one of an integer
