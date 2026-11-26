// Set<T>([a, b]) (#768): a Set is made of {a, b, c}, and its own
// sentence says so, where kelvinc said an array is not a value here:
// write a compound literal
let main():int32 {
    var s = Set<int64>([1, 2])
    return 0
}
// error: Set<i64> takes nothing, the elements in {a, b, c}, or a borrow of another, '&s'
