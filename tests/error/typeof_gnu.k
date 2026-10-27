// GNU C's __typeof__ is refused, with Kelvin's spellings (#398)
let main():i32 {
    let n = 1
    var x:__typeof__(n) = 2
    return 0
}
// error: '__typeof__' is a C compiler keyword; use typeof(x) or x.type
