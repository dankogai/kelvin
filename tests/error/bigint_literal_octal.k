// a BigInt literal is decimal, 0x hex or 0b binary (#508): a leading 0,
// C's octal, is none of them, as in JS
let main():int32 {
    let x = 017n
    return 0
}
// error: '017n': a BigInt literal is decimal, 0x hex or 0b binary, with no leading 0: C's octal is none of them
