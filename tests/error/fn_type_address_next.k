// error: '.next' is a property of pointers to data, and (i64):i64 is a function
let add(n:i64):i64 { return n + 1; }
let main():i32 {
    println((&add).next == nullptr);
    return 0;
}
