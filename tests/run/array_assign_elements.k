// what #648 leaves as it was: an array's elements are set, a row of an
// array of arrays by its elements, and a case of an enum with values set
// whole, its _set
enum e { none; c: [i64](2) }
let main():int32 {
    var a:[i64](2) = [1, 2]
    var m:[[i64](2)](2) = [[1, 2], [3, 4]]
    a[0] = 5
    m[1][0] = a[0]
    var v:e = {.none}
    v.c = [7, 8]
    println(a[0], " ", m[1][0], " ", v.c[1])
    return 0
}
// out: 5 5 8
