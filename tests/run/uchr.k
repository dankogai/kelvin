// uchr (#56): a codepoint on the stack, shown as its UTF-8 by print, a
// template and .cstr; for c in s gives one; .utf32 and .codepoint are the
// number, n.uchr and uchr(x) make one, U+FFFD where x is no codepoint
let main():i32 {
    var s = String("コガイ ダン")
    for c in s { print(c, "|") }
    println()
    var n = 0
    for c in s { if c == ' ' { n += 1 } }
    let e = uchr("é")
    let x = 0x1F600.uchr
    let bad = 0xD800.uchr
    var w = String()
    w += e
    w.append(x)
    w += ' '.uchr
    println(n, " ", e, " ", x, " ", bad.utf32.hex, " ", e.utf32, " ", e.codepoint, " ", u32(e) + 1, " ", i64(x))
    println(e.cstr, " ", `[${x}] ${e}`, " ", e.typename, " ", e.size, " ", w, " ", w.count)
    println(e < x, " ", e == 0xE9, " ", uchr(233) == e, " ", s.count)
    let s0:cstr := "日本"
    println(uchr(s0), " ", uchr(""), " ", uchr(0x110000))
    return 0
}
// out: コ|ガ|イ| |ダ|ン|
// out: 1 é 😀 0xfffd 233 233 234 128512
// out: é [😀] é uchr 4 é😀  3
// out: true true true 6
// out: 日 � �
// c: const kv_uchr c = (kv_uchr){kv_utf8_next(
// c: const kv_uchr e = (KV_UCHR_OF("é"));
// c: const kv_uchr x = kv_uchr_of(0x1F600);
// c: (e).cp
