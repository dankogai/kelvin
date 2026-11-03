// bv.append(x) changes bv, so bv is a var (#455)
let main():int32 {
    let bv = Bits()
    bv.append(true)
    return 0
}
// error: '.append' is a var method, which changes 'bv', a let: declare it with var
