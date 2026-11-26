// an array of arrays whose rows' count C computes is not printed whole
// (#776): its printer, a C function, cannot name the count, which was
// C's error, use of undeclared identifier; a row prints
let main():int32 {
    var n:int64 = 3
    var g:[[int64](n)](2)
    println(g[1])
    println(g)
    return 0
}
// error: an array of arrays of a count C computes is not printed whole: print its rows, println(g[i])
