// 'as uchr' makes no codepoint, as a uchr is a struct to C (#468):
// uchr("k") of text, or n.uchr of an integer, makes one
let main():int32 {
    println('k' as uchr)
    return 0
}
// error: 'as uchr' makes no codepoint: write uchr("k") of text, or n.uchr of an integer
