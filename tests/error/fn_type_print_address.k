// error: println cannot show a function: a function has no text
let add(n:i64):i64 { return n + 1; }
let main():i32 {
    println(&add);
    return 0;
}
