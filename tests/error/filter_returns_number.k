// error: '.filter' keeps what its function says true for, a bool, and this gives a number: compare it, as in 'x != 0'
let main():int32 {
    var xs:$[int64] = $[]
    xs += 1
    var ys = xs.filter { $0 + 1 }
    return 0
}
