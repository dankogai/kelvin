// An array of empty structs has size 0, so sizeof(a) / sizeof a[0] is 0 / 0:
// its count is its declared length, for .count, for, print, a template,
// .pretty and Array(a) (#499)
struct none { }
struct two { a: none; b: none }
struct after { e: none; n: i64 }
struct holder { xs: [none](5); k: i64 }
let N = 6

let walk(xs: [none](N)):i64 {
    var n = 0
    for x in xs { n += 1 }
    return n
}

let main():int32 {
    var a: [none](4)
    var b: [after](3)
    var c: [two](N)
    var g: [[none](3)](2)
    var h: holder
    var w: [none](N)
    h.k = 7
    println(a.count, " ", b.count, " ", c.count, " ", g.count, " ", g[0].count, " ", h.xs.count, " ", a.size)
    var n = 0
    for x in a { n += 1 }
    for y in c { n += 10 }
    for z in g[1] { n += 100 }
    println(n, " ", walk(w))
    println(a, " ", h)
    println(`g ${g}`)
    println(g[0].pretty)
    let arr = Array(a)
    println(arr.count)
    return 0
}
// out: 4 3 6 2 3 5 0
// out: 364 6
// out: [{}, {}, {}, {}] {xs: [{}, {}, {}, {}, {}], k: 7}
// out: g [[{}, {}, {}], [{}, {}, {}]]
// out: [
// out:   {},
// out:   {},
// out:   {}
// out: ]
// out: 4
// c: ((size_t)(4))
