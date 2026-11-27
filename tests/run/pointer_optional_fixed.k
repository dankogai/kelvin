// a fixed array read where a pointer's Optional goes is its first
// element's address (#784), as where a pointer is an element (#781):
// kc left it to C, which refused an array where a struct goes
let main():int32 {
    var b:[int64](2) = [4, 5]
    var q:int64^? = b
    var f:[float64](2) = [1.5, 2.5]
    var r:float64^? = none
    r = f
    println(q.is(some), " ", q!^, " ", r!^)
    return 0
}
// out: true 4 1.5
