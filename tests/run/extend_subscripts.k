// subscripts (#136): let [](i:I):R { } read as v[i], and var [](i:I):R
// { get { } set(v) { } } also written as v[i] = y and v[i] += y on the
// var that holds v; several indices read v[r, c], and subscripts
// overload by the indices' types; alone, let T[](i:I):R { }
struct Grid { w: int64; cells: [i64](6) }
extend Grid {
    let [](i:i64):i64 { .cells[i] }                  // read only
    var [](r:i64, c:i64):i64 {                           // read and written
        get { .cells[r * .w + c] }
        set(v) { .cells[r * .w + c] = v }
    }
    let total():i64 {                                    // self[i] in a method
        var t = 0
        for i in 0..<6 { t += self[i] }
        return t
    }
}
let Grid[](name:cstr):i64 { name[0] as i64 }             // alone, by another type
let Grid[](i:i32):i64 { -1 }                             // i32, against i64
struct Row { g: Grid }
let bump(p:Grid^) { p^[0, 1] += 10 }
enum Box { many: Array<i64>; one: i64 }                  // over #117's indexing
let Box[](i:i64):i64 { .is(many) ? .many[i] : .one }
let corner():Grid { var g:Grid = {2}; g[1, 1] = 4; return g }
let main():i32 {
    var g:Grid = {3}
    g[1, 2] = 7
    g[0, 0] += 5
    g[0, 0] *= 2
    println(g[5], " ", g[1, 2], " ", g[0], " ", g["A"], " ", g[0 as i32], " ", g.total())
    var row:Row = {}
    row.g[0, 1] = 1
    bump(&row.g)
    var gs:[Grid](2) = []
    gs[1][0, 0] = 3
    println(row.g[1], " ", gs[1][0], " ", corner()[3], " ", `${g[0, 0]}`)
    var b = Box.many($[10, 20, 30])
    let o = Box.one(4)
    println(b[1], " ", o[9])
    return 0
}
// out: 7 7 10 65 -1 17
// out: 11 3 4 10
// out: 20 4
// c: Grid__subscript_set(&(g), 1, 2, 7)
// c: Grid__subscript__i64__i64(&(g), 0, 0) + 5
