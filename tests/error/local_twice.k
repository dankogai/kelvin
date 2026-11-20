// a name declared twice in one block is kelvinc's error, where it was
// C's, redefinition of 'n' (#628); past ASCII it was so already (#385)
let main():int32 {
    let n = 1
    var n = 2
    println(n)
    return 0
}
// error: 'n' is declared already in this block
