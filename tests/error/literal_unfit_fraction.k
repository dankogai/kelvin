// a float with a fraction where an integer goes (#663), where C made it 1
let main():int32 {
    let x:i64 = 1.5
    println(x)
    return 0
}
// error: 1.5 has a fraction, and i64 has none: write an integer
