// a call through a function value takes as many arguments as its type has parameters (#158, #740)
let two(a:int64, b:int64):int64 { a + b }
let main():int32 {
    let f:(int64, int64):int64 := two
    println(f(1))
    return 0
}
// error: this function, of type (i64, i64):i64, takes 2 arguments, and it is given 1
