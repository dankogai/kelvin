// '.utf32' is a uchr's codepoint (#56): of a number, which is one
// already, it is an error that names .uchr, where it went to C (#297)
let main():int32 {
    let n:int64 = 65
    println(n.utf32)
    return 0
}
// error: '.utf32' is a uchr's codepoint, and this is a number, one already: '.uchr' makes a uchr of an integer (#297)
