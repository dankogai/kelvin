// an array of no count takes it from its elements (#762): with no value
// it has none, which was C's error, definition of variable with array
// type needs an explicit size or an initializer
let main():int32 {
    var v:[int64]
    return 0
}
// error: [i64] takes its count from its elements: write [i64](N), or the elements
