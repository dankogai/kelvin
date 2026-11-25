// a function's name where functions are the elements is the overload of
// their type (#764): in an Array's, a fixed array's and a Dictionary's
// literal, a struct's member, +=, append and insert, and an entry set;
// an anonymous function there takes the elements' type, $0 and all
struct ops { f:(int64):int64, n:int64 }
let twice(x:int64):int64 { x * 2 }
let twice(x:float64):float64 { x * 2.0 }
let main():int32 {
    var a:$[(int64):int64] = $[twice]
    a += twice
    a.append(twice)
    a.insert(0, twice)
    a += { $0 + 1 }
    a.append({ $0 + 2 })
    a.insert(0, { $0 * 10 })
    var total:int64 = 0
    for f in a { total += f(4) }
    println(a.count, " ", a[0](4), " ", a[1](4), " ", total)
    var r:[(float64):float64](2) = [twice, { $0 / 2.0 }]
    println(r[0](1.5), " ", r[1](1.5))
    var d:${String: (int64):int64} = ${"double": twice}
    d["more"] = twice
    d["inc"] = { $0 + 1 }
    var sum:int64 = 0
    for k, f in d { sum += f(5) }
    println(d.count, " ", sum)
    var o:ops = {twice, 1}
    var p:ops = {.f = twice, .n = 2}
    o.f := twice
    println(o.f(o.n), " ", p.f(p.n))
    return 0
}
// out: 7 40 8 83
// out: 3.0 0.75
// out: 3 26
// out: 2 4
