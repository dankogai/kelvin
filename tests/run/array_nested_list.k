// a [...] among the elements of Array([...]) is an Array in turn (#58):
// Array([[0], [0]]) is Array([Array([0]), Array([0])]), an Array<Array<i64>>,
// inferred or of the written type; Array<T>([]) is empty
struct point { x: i32, y: i32 }
let main():i32 {
    var m = Array([ [0], [0] ])
    println(m.count, " ", m[1].count, " ", m.typename)
    var n = Array([[[1, 2, 3]], [[4], [5, 6]]])
    println(n.count, " ", n[1].count, " ", n[1][1][1], " ", n.typename)
    var q = Array<Array<i64>>([[7, 8], []])
    println(q.count, " ", q[0][1], " ", q[1].count)
    var e = Array<i64>([])
    println(e.count)
    var ps = Array<Array<point>>([[{1, 2}, {.x = 3}]])
    println(ps[0][1].cstr, " ", ps[0].count)
    var ss = Array([[String("a")], [String("b"), String("c")]])
    for row in ss { for s in row { print(s) } print("|") }
    println(ss.typename)
    return 0
}
// out: 2 1 Array<Array<i64>>
// out: 2 2 6 Array<Array<Array<i64>>>
// out: 2 8 0
// out: 0
// out: {x: 3, y: 0} 2
// out: a|bc|Array<Array<String>>
// c: _kv_array_Array_i64 m = _kv_array_Array_i64_from((_kv_array_i64 [2]){_kv_array_i64_from((int64_t [1]){0}, 1), _kv_array_i64_from((int64_t [1]){0}, 1)}, 2);
// c: _kv_array_i64 e = (_kv_array_i64){0};
