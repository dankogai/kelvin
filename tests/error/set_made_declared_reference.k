// what a Set takes is said before := of a value is (#768), as kelvinc
// reads it, where kc said 's' is a value first
let main():int32 {
    var s := Set<int64>(5)
    return 0
}
// error: Set<i64> takes nothing, the elements in {a, b, c}, or a borrow of another, '&s'
