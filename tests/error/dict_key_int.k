// an integer-keyed Dictionary is read with an integer (#65)
let main():i32 {
    var d = $[1: 1]
    var y = d["x"]
    return 0
}
// error: a key of Dictionary<i64, i64> is an integer
