// error: '.cstr' text lives in a buffer of this function, which is gone once it returns
let show(x:i64, f:(i64):cstr) { println(f(x)); }
let main():i32 {
    show(255) { ($0 + 1).cstr }
    return 0;
}
