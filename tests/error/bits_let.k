// a let Bits does not change, bit by bit too (#387)
let main():int32 {
    let bv = Bits()
    bv[0] = true
    return 0
}
// error: 'bv' is a let and cannot change; declare it with var
