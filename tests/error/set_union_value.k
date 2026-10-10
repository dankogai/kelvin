// the set algebra takes a borrow of another Set (#71)
let main():i32 {
    var s = ${1, 2}
    var t = ${3}
    var u = s.union(t)
    return 0
}
// error: '.union' takes a borrow of another Set<i64>, '&other'
