// $"text" is String("text") and $[a, b, c] is Array([a, b, c]) (#62),
// nested lists included; in an anonymous function $[k] is its parameter
let apply(f:(i64):i64, x:i64):i64 { return f(x) }
let main():i32 {
    var s = $"I needed it"
    var m = $[[1, 0], [0, 1]]
    var e = $"a" "b"
    println(s, " ", s.count, " ", m[1][1], " ", m.typename, " ", e)
    var names = $[$"ann", $"bob"]
    for n in names { print(n, " ") }
    println(names.typename, " ", apply({ $[0] * 2 }, 21), " ", apply({ $0 + 1 }, 1))
    var one = $[7]
    var two = $[1, 2]
    println(one.count, " ", `${$"tpl"} ${two.count}`)
    return 0
}
// out: I needed it 11 1 Array<Array<i64>> ab
// out: ann bob Array<String> 42 2
// out: 1 tpl 2
// c: kv_string s = KV_STRING_OF("I needed it");
// c: _kv_array_Array_i64 m = _kv_array_Array_i64_from((_kv_array_i64 [2]){_kv_array_i64_from((int64_t [2]){1, 0}, 2), _kv_array_i64_from((int64_t [2]){0, 1}, 2)}, 2);
// c: kv_string e = KV_STRING_OF("a" "b");
