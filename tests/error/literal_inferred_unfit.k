// a literal past i64 in a declaration with no type, an i64, which C made -1 (#678)
let main():int32 {
    let x = 18446744073709551615
    println(x)
    return 0
}
// error: 18446744073709551615 does not fit i64, whose values are -9223372036854775808 to 9223372036854775807
