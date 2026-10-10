// JSON (#61, #65): an enum with values holding an Array and a Dictionary
// of itself, built from literals, walked, grown, copied, and freed by its
// block; each case of a switch is a block of its own (#63)
enum json { null; b: bool; n: f64; s: String; a: $[json]; o: $[String: json] }
let show(j:const json^) {
    switch j^ {
    case null: print("null")
    case b: print(j^.b)
    case n: print(j^.n)
    case s: print("\"", j^.s, "\"")
    case a:
        print("[")
        var first = true
        for x in j^.a {
            if !first { print(",") }
            first = false
            show(&x)
        }
        print("]")
    case o:
        print("{")
        var first = true
        for k, v in j^.o {
            if !first { print(",") }
            first = false
            print("\"", k, "\":")
            show(&v)
        }
        print("}")
    }
}
let main():i32 {
    var doc = json.o(${"name": json.s($"kelvin"), "tags": json.a($[json.s($"c"), json.n(11.0)]), "ok": json.b(true), "nil": json.null})
    show(&doc)
    println()
    doc.o["tags"].a += json.o(${"deep": json.n(1.5)})
    show(&doc)
    println()
    var copy = doc.copy()
    doc.o.remove("tags")
    show(&doc)
    println(" ", copy.o.count, " ", copy.o["tags"].a.count)
    return 0
}
// out: {"name":"kelvin","tags":["c",11.0],"ok":true,"nil":null}
// out: {"name":"kelvin","tags":["c",11.0,{"deep":1.5}],"ok":true,"nil":null}
// out: {"name":"kelvin","ok":true,"nil":null} 4 3
// c: KV_ARRAY_TYPE(struct json, _kv_array_json)
// c: KV_DICT_TYPE(_kv_dict_String_json)
// c: KV_ARRAY_FUNCS(struct json, _kv_array_json, _kv_json_free, _kv_json_copy)
// c: KV_DICT_FUNCS(kv_string, const uint8_t *, struct json, _kv_dict_String_json, KV_HASH_TEXT, KV_EQ_TEXT, KV_STORE_TEXT, KV_MISSING_TEXT, kv_string_free, kv_string_copy, _kv_json_free, _kv_json_copy)
