// a let BigInt's bit is not flipped (#531)
let main():int32 {
    let b = 5n
    b.bits[1].flip()
    return 0
}
// error: '.flip' is a var method, which changes 'b', a let: declare it with var
