// xs.gather(ix) and s.gather(ix) (#617): the elements of an Array of any
// type at the indices of a $[i64], in their order, each copied, and of a
// String its graphemes; ix is looked at, not moved, and the receiver and
// ix may be what an expression gives, held and freed after
struct point {
    x: i64
    y: i64
}

struct tag {
    name: String
    n: i64
}

let order():$[i64] { return $[2, 0, 2] }
let words():$[String] { return $["one", "two", "three"] }

let main():int32 {
    let pts = $[(point){1, 2}, (point){3, 4}]
    println(pts.gather($[1, 0, 1]))
    let tags = $[(tag){$"a", 1}, (tag){$"b", 2}]
    var picked = tags.gather($[1])
    picked[0].name += "!"
    println(picked, " ", tags)
    let grid:$[$[i64]] = $[[1], [2, 3], []]
    println(grid.gather($[2, 1]), " ", $[${"k": 1}, ${"j": 2}].gather($[1]))
    let big = $[BigInt(10) ** 30, BigInt(7)]
    println(big.gather($[1, 0]))
    let opt:$[i64?] = $[1, none]
    println(opt.gather($[1, 0]))
    println(words().gather(order()), " ", $[5, 6, 7].gather($[]), " ", $["x"].gather($[0, 0, 0]).count)
    let ix = order()
    let s = $"a👍🏽b\r\nc"                      // 👍🏽 and CR LF are each one grapheme
    println(s.gather(ix).count, " ", s.gather($[3, 1]) == $"\r\n👍🏽", " ", ix)
    println($"kelvin".gather($[5, 4, 3, 2, 1, 0]), " [", $"".gather($[]), "]")
    let r = (0..<3).map { 2 - $0 }
    println($["p", "q", "r"].gather(r), " ", $["p", "q"].gather(r.filter { $0 < 2 }))
    println(words().gather($[0]).typename, " ", $"ab".gather($[1]).typename)
    return 0
}
// out: [{x: 3, y: 4}, {x: 1, y: 2}, {x: 3, y: 4}]
// out: [{name: "b!", n: 2}] [{name: "a", n: 1}, {name: "b", n: 2}]
// out: [[], [2, 3]] [{"j": 2}]
// out: [7n, 1000000000000000000000000000000n]
// out: [none, some(1)]
// out: ["three", "one", "three"] [] 3
// out: 3 true [2, 0, 2]
// out: nivlek []
// out: ["r", "q", "p"] ["q", "p"]
// out: Array<String> String
