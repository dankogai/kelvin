// static goes before let, as for a variable (#45)
static twice(n:int64):int64 { n * 2 }
let main():int32 { return int32(twice(0)) }
// error: a function is declared with let: write 'static let twice(...)'
