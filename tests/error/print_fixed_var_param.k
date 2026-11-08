// a var array parameter is a pointer that may have moved: print cannot
// count it (#481)
let show(var xs:[i64](3)) {
    println(xs)
}
let main():int32 {
    return 0
}
// error: 'xs' is a var array parameter, a pointer in C that may have moved: show its elements, as in 'for i in 0..<n'
