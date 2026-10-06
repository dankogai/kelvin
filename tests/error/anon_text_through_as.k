// error: '.hex' text lives in a buffer of this function, which is gone once it returns
let show(n:i64, f:(i64):cstr) { println(f(n)); }
let main():i32 {
    show(255) { $0 > 0 ? $0.hex as cstr : "neg" as cstr }
    return 0;
}
