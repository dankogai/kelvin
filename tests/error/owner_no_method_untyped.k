// a method an owner has not is told in a declaration of no type
// written too (#789), as kelvinc says it before it asks the type: kc
// said 'n' needs a type
let main():int32 {
    var d:${String: int64} = ${:}
    var n = d.frob(1, 2)
    return 0
}
// error: a Dictionary has no method 'frob': has, find, get, remove, clear, reserve and copy, and the properties count and isEmpty
