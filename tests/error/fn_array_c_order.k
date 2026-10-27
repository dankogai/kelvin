// an array of functions is written [T](N), as any array (#403), not in C's order
let inc(n:i64):i64 { n + 1 }
let main():i32 {
    var hs:((i64):i64)[2]
    return 0
}
// error: an array of functions is written [T](N), as any array: [(i64):i64](4) (#403)
