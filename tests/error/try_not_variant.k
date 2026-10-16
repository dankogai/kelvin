// try takes a Result or an Optional (#76)
let f(n:int64):Result<i64, i32> {
    return try n
}
let main():i32 { return 0 }
// error: 'try' takes a Result or an Optional, and this is i64
