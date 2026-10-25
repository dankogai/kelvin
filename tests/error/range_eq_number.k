// a Range compares with a Range (#376)
let main():int32 {
    let b = 0..<3 == 3
    return 0
}
// error: a Range compares with a Range, and this is i64
