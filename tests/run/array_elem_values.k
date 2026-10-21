// an element of an Array is checked against its type (#256), as an entry
// of a Dictionary (#246): in a typed $[...], by xs[i] = v, and by append,
// += and insert of one element; text becomes a String, and a T or none
// an Optional, as a declaration's value does
// out: ["first", "a", "lit", "own", "b"]
// out: [1.0, 2.5, 3.0] [1, 1]
// out: [some(9), some(1), none, none, some(4), some(5)]
let main():int32 {
    var ws = $[$"a"]
    ws.append("lit")
    ws += $"own"
    ws.insert(0, "first")
    var b = $"b"
    ws += &b
    println(ws)
    var xs:Array<float64> = $[1, 2.5]
    xs += 3
    var ys = $[1]
    let zs = ys.copy()
    ys += &zs
    println(xs, " ", ys)
    var os:Array<int64?> = $[1, none]
    os += none
    os.append(4)
    os.insert(0, 9)
    os += 5
    println(os)
    return 0
}
