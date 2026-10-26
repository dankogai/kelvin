// a name past ASCII declared twice in a block is Kelvin's error (#385)
let main():int32 {
    let ♾️ = 1.0/0.0
    let ♾️ = 2.0
    return 0
}
// error: '♾️' is declared already in this block
