// xs += &x, xs.append(&x), xs.insert(i, &x) of one element (#206): the
// Array owns what it holds, so it takes a copy of x, by the copy of x's
// type: a String, a struct that owns, an Array, or a plain struct; as
// the message for xs += x says, which would copy unseen. &ys of an Array
// of the same type is still its elements
struct cell { v: int64; name: String }
struct plain { v: int64 }
let main():int32 {
    var names:$[String] = $[]
    var s = $"a"
    names += &s
    names.append(&s)
    s += "b"
    println(names, " ", s)
    var cells:$[cell] = $[]
    var c:cell = {1, $"x"}
    cells += &c
    cells.append(&c)
    c.v = 2
    cells.insert(0, &c)
    println(cells[0].v, cells[1].v, cells[2].v, " ", cells[2].name, " ", cells.count)
    var ps:$[plain] = $[]
    let p:plain = {3}
    ps += &p
    println(ps[0].v)
    var nested:$[$[int64]] = $[]
    var xs:$[int64] = $[1, 2]
    nested += &xs
    xs += 3
    var ys:$[int64] = $[4]
    xs += &ys                                   // an Array's elements
    println(nested, " ", xs)
    return 0
}
// out: ["a", "a"] ab
// out: 211 x 3
// out: 3
// out: [[1, 2]] [1, 2, 3, 4]
// c: _kv_array_cell_insert(&cells, 0, _kv_cell_copy(&c));
// c: _kv_array_i64_append_ref(&xs, &ys);
