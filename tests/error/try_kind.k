// an Optional's none cannot pass up through a Result (#76)
let find(n:int64):int64? { return none }
let f(n:int64):Result<int64, String> {
    return try find(n)
}
let main():int32 { return 0 }
// error: 'try' passes the 'none' up, and this function returns Result<i64, String>, not an Optional: switch on it, or 'if let'
