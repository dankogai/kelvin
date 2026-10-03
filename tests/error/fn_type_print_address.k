// error: println cannot show a function: a function has no text
add(n:i64):i64 { return n + 1; }
main():i32 {
    println(&add);
    return 0;
}
