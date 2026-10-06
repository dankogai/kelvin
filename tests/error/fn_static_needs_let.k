// static goes before let, as for a variable (#45)
static twice(n:i64):i64 { n * 2 }
let main():i32 { return i32(twice(0)) }
// error: a function is declared with let: write 'static let twice(...)'
