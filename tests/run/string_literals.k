// a string literal where a String is expected becomes a String (#70): a
// typed declaration, an assignment, an element, an entry, a member
struct bag { name: String }
let main():i32 {
    var s:String = "x"
    s = "y"
    var xs = Array<String>(["a", "b"])
    var d:${String: String} = {"k": "v"}
    var b:bag = {"n"}
    d["k2"] = "w"
    println(s, " ", xs[1], " ", d["k"], " ", d["k2"], " ", b.name, " ", xs.typename)
    return 0
}
// out: y b v w n Array<String>
// c: kv_string s = KV_STRING_OF("x");
// c: kv_string_assign(&s, KV_STRING_OF("y"));
// c: _kv_dict_String_String_set(&d, "k2", KV_STRING_OF("w"));
