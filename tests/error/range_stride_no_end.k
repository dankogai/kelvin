// a Range written without an end has no end to stride down from (#379)
let main():int32 {
    for i in (0...).stride(-2) { }
    return 0
}
// error: '.stride(-2)' walks a Range from its end, and 0... has none: take the first few, as in '.prefix(10).stride(-2)'
