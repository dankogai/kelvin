// error: i64 has no member 'baz'
// a literal in parentheses is a value, an i64 as arithmetic of literals is
// (#548, #669), and 5.baz is the error of a suffix
let main():int32 {
    println((5).baz)
    return 0
}
