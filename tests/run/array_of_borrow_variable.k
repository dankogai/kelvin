// Array<T>(p) and Array(p) of a borrow a variable holds are copies
// (#774), as of &a, which kc refused
let main():int32 {
    var b:$[int64] = $[1, 2, 3]
    let p := &b
    var a = Array<int64>(p)
    var c = Array(p)
    a += 4
    println(a.count, " ", b.count, " ", c.count, " ", c[2])
    return 0
}
// out: 4 3 3 3
