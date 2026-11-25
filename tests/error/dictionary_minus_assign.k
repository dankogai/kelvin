// a Dictionary has no -= (#763), as it has no +=
let main():int32 {
    var d:${String: int64} = ${"a": 1}
    d -= "a"
    return 0
}
// error: a Dictionary has no '-=': remove an entry with d.remove(k)
