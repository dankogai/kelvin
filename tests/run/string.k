// String (#55): codepoints as UTF-8 on a Bytes, an owner like it: made
// from text, appended with text, a codepoint or another String, walked by
// codepoint, counted, compared, copied, held by a struct, and borrowed
#import <string.h> as C
struct person { name: String; age: i64 }
let shout(s:String^):String {
    var r = String()
    for c in s^ {
        r += c == 'a' ? 'A' : c
    }
    r += "!"
    return r
}
let main():i32 {
    var s = String("héllo, κόσμε")
    s += " 🌍"
    s.append(0x1F600)
    println(s, " ", s.count, " ", s.bytes^.count, " ", s.typename, " ", s.size)
    var n = 0
    for c in s { if c > 127 { n += 1 } }
    let t = s.copy()
    println(n, " ", s == t, " ", t.cstr, " ", s.bytes^.isUTF8, " ", s.bytes^[0])
    var b = Bytes("plain")
    let u = b.string()
    println(u, " ", u.count, " ", b.isUTF8)
    var p:person = {String("Ada"), 36}
    p.name += " Lovelace"
    let loud = shout(&p.name)
    println(p.cstr, " ", loud)
    var bad = Bytes(2)
    bad[0] = 0xff
    println(bad.isUTF8)
    let e = String()
    println(e.count, " [", e, "] ", e.cstr.count)
    return 0
}
// out: héllo, κόσμε 🌍😀 15 27 String 32
// out: 8 true héllo, κόσμε 🌍😀 true 104
// out: plain 5 true
// out: {name: Ada Lovelace, age: 36} AdA LovelAce!
// out: false
// out: 0 [] 0
// c: __attribute__((cleanup(kv_string_free))) kv_string s = KV_STRING_OF("héllo, κόσμε");
// c: KV_STRING_APPEND(&s, " 🌍");
// c: kv_utf8_next(
// c: kv_string_from_bytes(&b)
// c: __attribute__((cleanup(_kv_person_free))) struct person p = {KV_STRING_OF("Ada"), 36};
