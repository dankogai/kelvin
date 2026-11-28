// a method an owner has not is told in an arm of a choice too (#792),
// in a declaration of no type written: kc said 'n' needs a type
let main():int32 {
    var a:$[int64] = $[1]
    var n = true ? a.frob() : 1
    return 0
}
// error: an Array has no method 'frob': append, insert, remove, pop, clear, reserve, compact, copy, join, joined and gather, and the properties count, isEmpty, capacity and at
