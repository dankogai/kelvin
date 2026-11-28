// a method an owner has not is told before a member of what it would
// give (#792): kc said this member is not known
let main():int32 {
    var a:$[int64] = $[1]
    var n = a.frob().count
    return 0
}
// error: an Array has no method 'frob': append, insert, remove, pop, clear, reserve, compact, copy, join, joined and gather, and the properties count, isEmpty, capacity and at
