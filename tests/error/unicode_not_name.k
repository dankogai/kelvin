// a symbol that is not a letter, a digit or an emoji is in no name (#385)
let main():int32 {
    let x→y = 1
    return 0
}
// error: '→' (U+2192) is neither an operator nor in a name: a name holds letters, digits, _ and emoji
