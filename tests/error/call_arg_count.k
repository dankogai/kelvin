// a call of a function of the program with fewer arguments than it takes
// is kelvinc's error, where it was C's, too few arguments (#627)
let add(a:i64, b:i64):i64 { a + b }
let main():int32 {
    println(add(1))
    return 0
}
// error: 'add' takes 2 arguments, and this call gives 1
