// error: this has no value, but this function has a result, of type i64
logged(x:i64):i64 { println(x) }
main():i32 {
    println(logged(1))
    return 0
}
