// try passes the err up, so the function must return a Result (#76)
let parse(s:cstr):Result<int64, String> { return int64(s) }
let twice(s:cstr):int64 {
    let n = try parse(s)
    return n * 2
}
let main():int32 { return 0 }
// error: 'try' passes the 'err' up, and this function returns i64, not a Result: switch on it, or 'if let'
