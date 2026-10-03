// error: println cannot show a function: a function has no text
add(a:i64, b:i64):i64 { return a + b; }
main():i32 {
    println(add);
    return 0;
}
