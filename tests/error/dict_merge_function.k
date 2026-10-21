// error: '.merge' calls its function with the two values of a key in both, i64, and keeps what it gives, and this is (i64, i64):bool
let main():int32 {
    var a = ${"x": 1}
    var b = ${"x": 2}
    a.merge(&b) { (p:int64, q:int64):bool in p > q }
    return 0
}
