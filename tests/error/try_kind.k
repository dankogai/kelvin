// an Optional's none cannot pass up through a Result (#76)
let find(n:int64):i64? { return none }
let f(n:i64):Result<i64, String> {
    return try find(n)
}
let main():i32 { return 0 }
// error: 'try' passes the 'none' up, and this function returns Result<i64, String>, not an Optional: switch on it, or 'if let'
