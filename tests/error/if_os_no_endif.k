// #if ends with #endif (#643)
let main():int32 {
    #if os(Windows)
    println("x")
    return 0
}
// error: '#if' has no '#endif'
