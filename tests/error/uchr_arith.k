// a uchr has no arithmetic: its codepoint is .utf32 (#56)
let main():i32 {
    let c = uchr("a")
    let d = c + 1
    return 0
}
// error: a uchr has no operator '+': its codepoint is 'c.utf32', a u32
