// extern and static go before let, for a function as for a variable (#45)
extern let half(n:i64):i64
static let twice(n:i64):i64 { n * 2 }
let main():i32 {
    println(half(6), " ", twice(4))
    return 0
}
let half(n:i64):i64 { n / 2 }
// out: 3 8
// c: extern int64_t half(int64_t n);
