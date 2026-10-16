// the err passes up as it is, so its type must be the function's (#76)
let f(n:int64):Result<i64, i32> { return err(1) }
let g(n:i64):Result<i64, String> {
    return try f(n)
}
let main():i32 { return 0 }
// error: 'try' passes the 'err' up as it is, and it is i32 where this function's is String
