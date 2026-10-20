// a[i].f = g() where g grows a (#205): C finds the place and calls g in
// no order it promises, and gcc found the place first, so the value went
// where a had been. The value is made first: an assignment's, a compound
// one's, an owner's, and the arguments of a method of an element
struct cell { v: int64; name: String }
var cells:$[cell]
var nums:$[int64]
var names:$[String]
let grow():int64 {
    for i in 0..<100 {
        let c:cell = {i, $"x"}
        cells += c.copy()
        nums += i
        names += $"n"
    }
    return 7
}
let word():String {
    grow()
    return $"grown"
}
let main():int32 {
    let c:cell = {0, $"first"}
    cells += c.copy()
    nums += 0
    names += $"a"
    cells[0].v = grow()
    nums[0] = grow()
    nums[0] += grow()
    names[0] = word()
    cells[0].name += word()
    println(cells[0].v, " ", nums[0], " ", names[0], " ", cells[0].name, " ", cells.count)
    return 0
}
// out: 7 14 grown firstgrown 501
// c: __typeof__((*_kv_array_cell_at(&cells, 0)).v) _kv_value0 = grow();
// c: __auto_type _kv_arg0 = word();
