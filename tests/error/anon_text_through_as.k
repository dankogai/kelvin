// error: '.hex' text lives in a buffer of this function, which is gone once it returns
show(n:i64, f:(i64):cstr) { println(f(n)); }
main():i32 {
    show(255) { $0 > 0 ? $0.hex as cstr : "neg" as cstr }
    return 0;
}
