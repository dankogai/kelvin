// r.contains takes an integer (#374)
let main():int32 {
    let b = (0..<3).contains(1.5)
    return 0
}
// error: '.contains' takes an integer, and this is a floating-point number
