// a method a Dictionary has not is told with what it has (#787), as
// kelvinc says it: kc said this method is not known
let main():int32 {
    var d:${String: int64} = ${:}
    d.set("k", 1)
    return 0
}
// error: a Dictionary has no method 'set': has, find, get, remove, clear, reserve and copy, and the properties count and isEmpty
