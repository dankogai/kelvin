// past i64, by one (#663)
let main():int32 {
    let a:i64 = 9223372036854775808
    println(a)
    return 0
}
// error: 9223372036854775808 does not fit i64, whose values are -9223372036854775808 to 9223372036854775807
