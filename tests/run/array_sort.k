// xs.sort() in place and xs.sorted() a new Array (#185), by a comparator,
// true where its first goes before its second, or by <: numbers by value,
// a String, a Bytes or a cstr by its bytes, codepoint order for UTF-8, a
// uchr by its codepoint, a struct by its own operator <; a stable sort
struct point { x: int64; y: int64 }
let <(a:point, b:point):bool { a.x < b.x || (a.x == b.x && a.y < b.y) }
let descending(a:int64, b:int64):bool { a > b }
let main():int32 {
    var up = $[3, 2, 1, 0].sorted{ $0 < $1 }
    var a = $[3, 2, 1, 0]
    var c = a.sorted()
    var d = a.sorted(descending)
    a.sort()
    println(up, " ", a, " ", c, " ", d)
    var names = $[$"bob", $"ann", $"émile", $"Zed", $"ann2"]
    var byLen = names.sorted { $0.count < $1.count }        // stable: bob before ann, both of 3
    names.sort()
    println(names, " ", byLen)
    var ps = $[(point){2, 1}, (point){1, 5}, (point){1, 2}]
    ps.sort()
    var cs = $["pear", "apple", "fig"]
    cs.sort()
    var fs = $[2.5, -1.0, 0.5]
    var fsorted = fs.sorted()
    var us = $[uchr("γ"), uchr("a"), uchr("é")]
    us.sort()
    println(ps, " ", cs, " ", fsorted, " ", us[0], us[1], us[2])
    var bs = $[Bytes([2]), Bytes([1, 9]), Bytes([1])]
    bs.sort()
    var be = bs.map { $0.escape() }
    var one = $[7]
    one.sort()
    var none = Array<int64>()
    none.sort { $0 > $1 }
    var top = $[5, 1, 4].sorted { $0 > $1 }.map { $0 * 10 }
    println(be, " ", one, " ", none.count, " ", top)
    var s1 = $"apple"
    var s2 = $"banana"
    var s3 = $"apple"
    println(s1 < s2, " ", s1 >= s2, " ", s1 <= s3, " ", s2 > s1)
    return 0
}
// out: [0, 1, 2, 3] [0, 1, 2, 3] [0, 1, 2, 3] [3, 2, 1, 0]
// out: ["Zed", "ann", "ann2", "bob", "émile"] ["bob", "ann", "Zed", "ann2", "émile"]
// out: [{x: 1, y: 2}, {x: 1, y: 5}, {x: 2, y: 1}] ["apple", "fig", "pear"] [-1, 0.5, 2.5] aéγ
// out: ["\\x01", "\\x01\\x09", "\\x02"] [7] 0 [50, 40, 10]
// out: true false true true
