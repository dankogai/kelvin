// $[T] is the type Array<T> (#64), and $[[T]] Array<Array<T>>: in
// variables, parameters, results, members, pointers and signatures
let total(xs:$[i64]^):i64 {
    var n:i64 = 0
    for x in xs^ { n += x }
    return n
}
let rows():$[[i64]] {
    var r:$[[i64]] = $[[1, 0], [0, 1]]
    return r
}
struct grid { cells: $[[i64]]; name: String }
let main():i32 {
    var va:$[[i64]] = $[[1, 0], [0, 1]]
    var vb:$[i64]
    vb += 3; vb += 4
    println(va.typename, " ", va[1][1], " ", vb.typename, " ", total(&vb))
    var p:$[i64]^ := &vb
    var r = rows()
    println(p^.count, " ", r[0][0], " ", rows().typename)
    var s:$[String] = $[$"a", $"b"]
    println(s[1], " ", s.typename, " ", s.count)
    var g:grid = {rows(), $"g"}
    println(g.cells[1][1], " ", g.name, " ", g.typename)
    let f := { (xs:$[i64]^):i64 in xs^.count }
    println(f(&vb))
    return 0
}
// out: Array<Array<i64>> 1 Array<i64> 7
// out: 2 1 Array<Array<i64>>
// out: b Array<String> 2
// out: 1 g grid
// out: 2
// c: int64_t total(_kv_array_i64 *const xs)
// c: _kv_array_Array_i64 rows(void)
// c: _kv_array_Array_i64 cells;
