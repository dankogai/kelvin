// try passes the err up, so the function must return a Result (#76)
let parse(s:cstr):Result<i64, String> { return i64(s) }
let twice(s:cstr):i64 {
    let n = try parse(s)
    return n * 2
}
let main():i32 { return 0 }
// error: 'try' passes the 'err' up, and this function returns i64, not a Result: switch on it, or 'if let'
