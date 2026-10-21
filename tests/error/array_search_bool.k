// error: '.lastIndex' looks for what its function says true for, a bool, and this gives a number
let main():int32 {
    var xs = $[1, 2]
    println(xs.lastIndex { $0 + 1 })
    return 0
}
