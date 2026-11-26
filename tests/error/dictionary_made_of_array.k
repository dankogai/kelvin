// Dictionary<K, V>([k: v]) (#768): its entries are written in {...}
let main():int32 {
    var d = Dictionary<String, int64>(["a": 1])
    return 0
}
// error: Dictionary<String, i64> takes nothing, the entries in {k: v, ...}, or a borrow of another, '&d'
