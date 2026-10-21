// error: a Dictionary has no '.firstIndex': its values are found by key, '.firstKey'
let main():int32 {
    var d = ${"a": 1}
    println(d.firstIndex(1))
    return 0
}
