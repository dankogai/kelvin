// error: this has no value, but this function has a result, of type i64
let logged(x:i64):i64 { (x, println(x)) }
let main():i32 {
    println(logged(1))
    return 0
}
