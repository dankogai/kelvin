// a Range written without an end has no end to walk back from (#378)
let main():int32 {
    for i in (0...).reversed() { }
    return 0
}
// error: '.reversed()' walks a Range from its end, and 0... has none: take the first few, as in '.prefix(10).reversed()'
