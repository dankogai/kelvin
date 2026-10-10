// Dictionary<K, V> (#65): a hash map on the heap, an owner; $[k: v] and
// $[K: V]; d[k] checked, d[k] = v, has, find, get, remove, clear, copy;
// for k, v in d in the order added; String and integer keys; owners as
// values, nested
let total(d:$[String: i64]^):i64 {
    var n:i64 = 0
    for k, v in d^ { n += v }
    return n
}
let main():i32 {
    var ages = $["ann": 31, "bob": 42]
    ages["cy"] = 7
    ages["ann"] += 1
    println(ages.count, " ", ages["ann"], " ", ages.has("bob"), " ", ages.has("dan"), " ", ages.typename)
    for k, v in ages { print(k, "=", v, " ") }
    println(total(&ages))
    println(ages.remove("bob"), " ", ages.remove("bob"), " ", ages.count, " ", ages.get("bob", -1), " ", ages.get("cy", -1))
    ages["dan"] = 9
    for k in ages { print(k, " ") }
    println()
    let p := ages.find("cy")
    let q := ages.find("zed")
    println(p.isNull, " ", p^, " ", q.isNull)
    var squares:$[i64: i64]
    for i in 0..<100 { squares[i] = i * i }
    println(squares.count, " ", squares[99], " ", squares.has(100), " ", squares.typename)
    var copy = ages.copy()
    copy["ann"] = 0
    println(ages["ann"], " ", copy["ann"], " ", copy.count)
    var words:$[String: $[String]] = $[:]
    words["a"] = $[$"apple"]
    words["a"] += $"avocado"
    words["b"] = $[$"banana"]
    for k, v in words { print(k, ":", v.count, " ") }
    println(words["a"][1])
    var names = Dictionary<String, String>(["x": $"ex"])
    names["y"] = $"why"
    var s = $"x"
    println(names[s], " ", names["y"].count, " ", names.typename)
    var nested = $[1: $[2: $"two"]]
    println(nested[1][2], " ", nested.typename)
    var e:Dictionary<i64, i64> = Dictionary<i64, i64>()
    println(e.count, " ", e.size)
    squares.clear()
    println(squares.count)
    return 0
}
// out: 3 32 true false Dictionary<String, i64>
// out: ann=32 bob=42 cy=7 81
// out: true false 2 -1 7
// out: ann cy dan 
// out: false 7 true
// out: 100 9801 false Dictionary<i64, i64>
// out: 32 0 3
// out: a:2 b:1 avocado
// out: ex 3 Dictionary<String, String>
// out: two Dictionary<i64, Dictionary<i64, String>>
// out: 0 48
// out: 0
// c: KV_DICT(kv_string, const uint8_t *, int64_t, _kv_dict_String_i64, KV_HASH_TEXT, KV_EQ_TEXT, KV_STORE_TEXT, KV_MISSING_TEXT, kv_string_free, kv_string_copy, KV_PLAIN_FREE, KV_PLAIN_COPY)
// c: KV_DICT(int64_t, int64_t, int64_t, _kv_dict_i64_i64, KV_HASH_INT, KV_EQ_INT, KV_STORE_INT, KV_MISSING_INT, KV_PLAIN_FREE, KV_PLAIN_COPY, KV_PLAIN_FREE, KV_PLAIN_COPY)
// c: _kv_dict_String_i64_set(&ages, "cy", 7);
// c: (*_kv_dict_String_i64_at(&ages, "ann")) += 1;
// c: _kv_dict_String_String_at(&names, kv_bytes_cstr(&(s).b))
