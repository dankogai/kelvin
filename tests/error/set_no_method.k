// a method a Set has not is told with what it has (#787)
let main():int32 {
    var s:${String} = ${"a"}
    s.frob()
    return 0
}
// error: a Set has no method 'frob': insert, has, remove, clear, reserve, copy, union, intersection and difference, and the properties count, isEmpty and elements
