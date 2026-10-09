// Array([...]) (#58): the elements written, T inferred from them, or
// given as Array<T>([...]); Array(a) of a fixed array and Array(&other)
// infer T too
let squares(n:i64):Array<i64> {
    var xs = Array<i64>()
    for i in 0..<n { xs += i * i }
    return xs
}
let main():i32 {
    var va = Array([0, 1, 2, 3])
    println(va.count, " ", va[3], " ", va.typename)
    var vb = Array<f64>([1, 2.5])
    println(vb.count, " ", vb[1], " ", vb.typename)
    var a = [7, 8, 9]
    var vc = Array(a)
    println(vc.count, " ", vc[2], " ", vc.typename)
    var vd = Array(&vc)
    vd += 10
    println(vd.count, " ", vc.count)
    var names = Array([String("ann"), String("bob")])
    for n in names { print(n, " ") }
    println(names.typename)
    var rows = Array([Array([1, 2]), squares(3)])
    println(rows.count, " ", rows[1][2], " ", rows.typename)
    var bs = Array(["x", "yz"])
    println(bs[1], " ", bs.typename)
    var cs = Array(['a', 'b'])
    println(cs.count, " ", cs.typename)
    var ts = Array([true, false])
    println(ts[1], " ", ts.typename)
    return 0
}
// out: 4 3 Array<i64>
// out: 2 2.5 Array<f64>
// out: 3 9 Array<i64>
// out: 4 3
// out: ann bob Array<String>
// out: 2 4 Array<Array<i64>>
// out: yz Array<cstr>
// out: 2 Array<u8>
// out: false Array<bool>
// c: _kv_array_i64 va = _kv_array_i64_from((int64_t [4]){0, 1, 2, 3}, 4);
// c: _kv_array_f64 vb = _kv_array_f64_from((double [2]){1, 2.5}, 2);
// c: _kv_array_i64 vc = _kv_array_i64_from(a, sizeof (a) / sizeof (a)[0]);
// c: _kv_array_i64 vd = _kv_array_i64_copy(&vc);
// c: _kv_array_String names = _kv_array_String_from((kv_string [2]){KV_STRING_OF("ann"), KV_STRING_OF("bob")}, 2);
