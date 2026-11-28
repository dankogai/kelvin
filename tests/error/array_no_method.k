// a method an Array has not is told with what it has (#787)
let main():int32 {
    var a:$[int64] = $[1]
    a.frob()
    return 0
}
// error: an Array has no method 'frob': append, insert, remove, pop, clear, reserve, compact, copy, join, joined and gather, and the properties count, isEmpty, capacity and at
