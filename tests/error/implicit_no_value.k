// error: this has no value, but this function has a result, of type i64
log(x:i64) { println("log ", x) }
f(x:i64):i64 { log(x) }
main():i32 {
    println(f(1))
    return 0
}
