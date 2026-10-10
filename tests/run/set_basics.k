// Set<T> (#71): a hash set on the heap, an owner; ${a, b, c} and ${T};
// insert (also +=), has, remove, union, intersection, difference, copy,
// elements, for x in s in the order added; integer and String elements
struct tags { names: ${String}; ids: Set<i64> }
let count_odd(s:${i64}^):i64 {
    var n:i64 = 0
    for x in s^ { if x % 2 == 1 { n += 1 } }
    return n
}
let main():i32 {
    var s = ${3, 1, 4, 1, 5}
    println(s.count, " ", s.has(4), " ", s.has(2), " ", s.typename, " ", count_odd(&s))
    s += 9
    s += 3
    println(s.insert(2), " ", s.insert(2), " ", s.remove(1), " ", s.remove(1), " ", s.count)
    for x in s { print(x, " ") }
    println()
    var t:${i64} = ${}
    t += &s
    t += 100
    var u = s.union(&t)
    var i = s.intersection(&t)
    var d = t.difference(&s)
    println(t.count, " ", u.count, " ", i.count, " ", d.count, " ", d.has(100))
    var words = ${"to", "be", "or", "not", "to", "be"}
    var w = $"be"
    println(words.count, " ", words.has("or"), " ", words.has(w), " ", words.has("x"), " ", words.typename)
    var es = words.elements
    for e in es { print(e, " ") }
    println(es.typename)
    var c = words.copy()
    c += "new"
    println(words.count, " ", c.count)
    var g:tags = {{"a", "b"}, ${7}}
    g.names += "c"
    println(g.names.count, " ", g.ids.has(7))
    var sets = $[${1, 2}, Set<i64>({3})]
    println(sets[1].has(3), " ", sets.typename)
    var e = Set<String>()
    var f = Set<String>(&words)
    println(e.count, " ", f.count, " ", e.typename)
    return 0
}
// out: 4 true false Set<i64> 3
// out: true false true false 5
// out: 3 4 5 9 2 
// out: 6 6 5 1 true
// out: 4 true true false Set<String>
// out: to be or not Array<String>
// out: 4 5
// out: 3 true
// out: true Array<Set<i64>>
// out: 0 4 Set<String>
// c: KV_SET(int64_t, int64_t, _kv_set_i64, KV_HASH_INT, KV_EQ_INT, KV_STORE_INT, KV_LK_INT, KV_PLAIN_FREE, KV_PLAIN_COPY)
// c: _kv_set_i64_insert(&s, 9);
// c: _kv_set_i64_insert_all(&t, &s);
// c: _kv_set_i64 u = _kv_set_i64_union(&s, &t);
