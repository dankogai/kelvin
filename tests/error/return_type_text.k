// what a function returns is of its result type, in kelvinc's words, as
// a declaration's value is (#627): C said incompatible pointer to integer
let size():i64 {
    return "big"
}
let main():int32 {
    println(size())
    return 0
}
// error: 'size' returns an i64, and this is text
