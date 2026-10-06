// error: this has no value, but this function has a result, of type i64
let log(x:i64) { println("log ", x) }
let f(x:i64):i64 { log(x) }
let main():i32 {
    println(f(1))
    return 0
}
