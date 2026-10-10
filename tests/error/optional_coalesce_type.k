// ?? takes an Optional on its left (#72)
let main():i32 {
    var n:i64 = 1
    var y = n ?? 1
    return 0
}
// error: '??' takes an Optional on its left, and this is i64
