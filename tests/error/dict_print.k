// a Dictionary has no text yet (#65)
let main():i32 {
    var d = ${"a": 1}
    println(d)
    return 0
}
// error: a Dictionary has no text yet: println its entries, as in 'for k, v in d'
