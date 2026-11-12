// a let BigInt's bit is not set (#531)
let main():int32 {
    let b = 5n
    b.bits[1] = true
    return 0
}
// error: 'b' is a let and cannot change; declare it with var
