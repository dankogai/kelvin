// d[k] = v where the key is a String an expression gives (#209): the key
// is held in a temporary around the place (#187), and the assignment
// goes inside it, so that d[$"a"] = 1 sets the entry, as d["a"] = 1
// does, where its C could not assign; += and the rest change the value
let key():String { return $"k" }
let main():int32 {
    var d:Dictionary<String, int64> = ${:}
    d[$"a"] = 1
    d[key()] = 2
    d[$"a"] = 3
    d[$"a"] += 10
    var e:Dictionary<String, String> = ${:}
    e[$"x"] = $"one"
    e[$"x"] = $"two"
    e[$"x"] += "!"
    var xs:$[int64] = $[0, 0, 0]
    xs[$"abc".count - 1] = 9
    xs[$"ab".count - 1] += 4
    println(d, " ", e, " ", xs)
    return 0
}
// out: {"a": 13, "k": 2} {"x": "two!"} [0, 4, 9]
// c: _kv_dict_String_i64_set(&d, kv_bytes_cstr(&(_kv_tmp1).b), 1); });
