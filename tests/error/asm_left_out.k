// GNU C's assembly is left out on purpose (#399): C's own, in #inline C
let main():i32 {
    __asm__ __volatile__("nop")
    return 0
}
// error: '__asm__' is a C compiler keyword; use #inline C { __asm__ __volatile__("..."); }, as C
