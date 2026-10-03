// error: an anonymous function cannot be passed here: the parameter is i64, not a function
add(a:i64, b:i64):i64 { return a + b; }
main():i32 {
    println(add(1) { $0 });
    return 0;
}
