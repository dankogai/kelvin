// a Range's methods are a Sequence's, lazy and prefix (#373), count and contains (#374), its bounds (#375)
let main():int32 {
    let n = (0..<3).first
    return 0
}
// error: a Range has lowerBound, upperBound, count, contains, map, filter, reduce, flatMap, lazy and prefix, and '.first' is none of them
