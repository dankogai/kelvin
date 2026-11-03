// ':uchr' of a number makes no codepoint either (#468)
let main():int32 {
    let n = 107
    let c = n:uchr
    println(c)
    return 0
}
// error: ':uchr' makes no codepoint: write uchr("k") of text, or n.uchr of an integer
