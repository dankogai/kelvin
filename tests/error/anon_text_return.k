// error: '.hex' text lives in a buffer of this function, which is gone once it returns
let show(x:i64, f:(i64):cstr) { println(f(x)); }
let main():i32 {
    show(255) { return $0.hex; }
    return 0;
}
