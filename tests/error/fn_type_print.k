// error: println cannot show a function: a function has no text
let add(a:i64, b:i64):i64 { return a + b; }
let main():i32 {
    println(add);
    return 0;
}
