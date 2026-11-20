// x^ reads through a pointer, and a number is none: kelvinc's error, where
// C said indirection requires pointer operand (#627)
let main():int32 {
    let n = 1
    println(n^)
    return 0
}
// error: '^' reads what a pointer points at, and 'n' is an i64
