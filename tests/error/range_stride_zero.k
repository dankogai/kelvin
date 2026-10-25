// a step of 0 never moves (#379)
let main():int32 {
    for i in (0..<5).stride(0) { }
    return 0
}
// error: '.stride(0)' never moves: step by a number other than 0
