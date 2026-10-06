// error: an anonymous function cannot be passed here: the parameter is i64, not a function
let add(a:i64, b:i64):i64 { return a + b; }
let main():i32 {
    println(add(1) { $0 });
    return 0;
}
