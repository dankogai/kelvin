// a Range written without an end has no count (#374)
let main():int32 {
    let n = (0...).count
    return 0
}
// error: '.count' counts a Range to its end, and 0... has none: take the first few, as in '.prefix(10).count'
