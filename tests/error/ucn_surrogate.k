// a \u escape is a codepoint (#292): a surrogate is none, which C's
// universal character name refused in C's words
let main():int32 {
    println("\u{D800}")
    return 0
}
// error: \u{D800} is no codepoint: a surrogate, D800 to DFFF, or past 10FFFF (#292)
