// ++ and -- are postfix only (#51)
let main():i32 {
    var p:cstr := "hi"
    ++p
    return 0
}
// error: Kelvin has no prefix '++': a pointer steps with 'p++' as a statement (#51), and a number with 'x += 1'
