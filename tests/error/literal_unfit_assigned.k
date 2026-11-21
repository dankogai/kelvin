// of an assignment (#663)
let main():int32 {
    var c:i8 = 0
    c = 128
    println(c)
    return 0
}
// error: 128 does not fit i8, whose values are -128 to 127
