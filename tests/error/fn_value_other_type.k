// a function where one of another function type goes is Kelvin's error
// (#748), an anonymous function that writes its parameters too, where
// it was C's, incompatible function pointer types
let num(f:(int64):int64):int64 { f(1) }
let main():int32 {
    println(num({ (x:float64):int64 in 1 }))
    return 0
}
// error: this is (f64):i64, where (i64):i64 goes
