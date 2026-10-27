// asm(...) is GNU C's assembly (#399), written in #inline C
let main():i32 {
    asm("nop")
    return 0
}
// error: assembly is C's, a GNU extension, left out on purpose: write it in #inline C { __asm__ __volatile__("..."); }
