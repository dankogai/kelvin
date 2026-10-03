// error: '.next' is a property of pointers to data, and (i64):i64 is a function
add(n:i64):i64 { return n + 1; }
main():i32 {
    println((&add).next == nullptr);
    return 0;
}
