// a \u escape is \u{X}, \uXXXX or \UXXXXXXXX (#292): \u12 is none
let main():int32 {
    println("\u12")
    return 0
}
// error: a \u escape is \u{X}, \uXXXX or \UXXXXXXXX: a codepoint in hex digits (#292)
