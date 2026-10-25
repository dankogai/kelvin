// a Range's methods are a Sequence's, lazy and prefix (#373)
let main():int32 {
    let n = (0..<3).count
    return 0
}
// error: a Range has map, filter, reduce, flatMap, lazy and prefix, and '.count' is none of them
