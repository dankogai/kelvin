// names are compared as written: ♾ and ♾️ (with U+FE0F) are two (#385)
let main():int32 {
    let ♾️ = 1.0/0.0
    println(♾)
    return 0
}
// error: '♾' is not known, but '♾️', which differs from it by a variation selector, U+FE0F, is
