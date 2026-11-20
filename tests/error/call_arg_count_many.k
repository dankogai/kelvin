// and with more (#627)
let twice(a:i64):i64 { a * 2 }
let main():int32 {
    println(twice(1, 2))
    return 0
}
// error: 'twice' takes 1 argument, and this call gives 2
