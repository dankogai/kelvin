// error: this function, of type (i64), has no result, so its body would discard this value
let each(n:i64, f:(i64)) { for i in 0..<n { f(i); } }
let main():i32 {
    each(3) { $0 + 1 }
    return 0;
}
