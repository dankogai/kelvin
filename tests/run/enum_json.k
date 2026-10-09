// an enum with values that owns and holds an Array of itself (#61): JSON;
// freed by its block, moved into a case by T.n(x), copied by .copy(),
// walked, set (freeing what it held), switched on
enum json { null; b: bool; n: f64; s: String; a: Array<json> }
let count(j:const json^):i64 {
    if j^.is(a) {
        var n:i64 = 1
        for x in j^.a { n += count(&x) }
        return n
    }
    return 1
}
let main():i32 {
    var j = json.a(Array([json.n(1.0), json.s(String("x")), json.null]))
    for x in j.a { print(x.cstr, " ") }
    println(j.a.count, " ", count(&j))
    j.a += json.b(true)
    j.a += json.a(Array([json.null, json.null]))
    var k = j.copy()
    var s = String("moved")
    var t = json.s(s)
    j.s = String("set")
    println(j.cstr, " ", t.cstr, " ", k.a.count, " ", k.a[3].cstr, " ", count(&k))
    k.a[1].s += "yz"
    println(k.a[1].cstr, " ", k.a[4].a[0].cstr)
    var m:json = {.s = String("init")}
    m = json.n(3.0)
    println(m.cstr, " ", m.n + 1.0)
    switch (k.a[0]) {
    case n: println("number ", k.a[0].n); break
    case s: println("text"); break
    default: println("other")
    }
    return 0
}
// out: n(1) s(x) null 3 4
// out: s(set) s(moved) 5 b(true) 8
// out: s(xyz) null
// out: n(3) 4.0
// out: number 1.0
// c: KV_ARRAY_TYPE(struct json, _kv_array_json)
// c: __attribute__((unused)) static inline void _kv_json_free(struct json *self);
// c: KV_ARRAY_FUNCS(struct json, _kv_array_json, _kv_json_free, _kv_json_copy)
// c: case 4: _kv_v.u.a = _kv_array_json_copy(&self->u.a); break;
// c: __attribute__((cleanup(_kv_json_free))) struct json j = _kv_json_make_a(_kv_array_json_from((struct json [3]){_kv_json_make_n(1.0), _kv_json_make_s(KV_STRING_OF("x")), _kv_json_make_null()}, 3));
// c: struct json t = _kv_json_make_s(kv_string_take(&s));
// c: _kv_json_set_s(&j, KV_STRING_OF("set"));
