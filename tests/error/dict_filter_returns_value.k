// error: '.filter' keeps what its function says true for, a bool, and this gives i64: compare it, as in 'x != 0'
let main():int32 {
    var d = ${"a": 1}
    var e = d.filter { v in v }
    return 0
}
