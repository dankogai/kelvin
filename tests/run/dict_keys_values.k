// d.keys and d.values (#66): Arrays of copies of a Dictionary's keys and
// values, in the order the entries were added, which a variable owns
let main():i32 {
    var ages = $["ann": 31, "bob": 42, "cy": 7]
    ages.remove("bob")
    var ks = ages.keys
    var vs = ages.values
    for k in ks { print(k, " ") }
    for v in vs { print(v, " ") }
    println(ks.typename, " ", vs.typename, " ", ks.count)
    var nest = $[1: $[$"a", $"b"], 2: $[$"c"]]
    var inner = nest.values
    inner[0] += $"z"
    println(inner.count, " ", inner[0][2], " ", nest[1].count, " ", inner.typename)
    return 0
}
// out: ann cy 31 7 Array<String> Array<i64> 2
// out: 2 z 2 Array<Array<String>>
// c: static inline _kv_array_String _kv_dict_String_i64_keys(const _kv_dict_String_i64 *d)
// c: v.at[v.count++] = kv_string_copy(&d->at[i].key);
// c: _kv_array_String ks = _kv_dict_String_i64_keys(&ages);
