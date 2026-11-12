// '.utf32' was a uchr's codepoint (#56), and uchr is no more (#528): of
// a number, a codepoint already, it is an error that says so
let main():int32 {
    let n:int64 = 65
    println(n.utf32)
    return 0
}
// error: '.utf32' was a uchr's codepoint, and uchr is no more (#528): a codepoint is a u32, the number itself
