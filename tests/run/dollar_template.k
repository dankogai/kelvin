// $`a${x}b` (#67): a template built as a String on the heap, with no
// bound: a String's text whole, a uchr as its character, a struct's text,
// numbers and properties as the bounded template shows them
struct point { x: i32; y: i32 }
let main():i32 {
    let name:cstr := "Kelvin"
    let n:i64 = 42
    var s = $`Hello, ${name}! ${n} / 4.0 = ${n / 4.0}`
    println(s, " ", s.count, " ", s.typename)
    var big = $"x"
    for _ in 0..<300 { big += "y" }
    var t = $`[${big}] ${big.count} ${true} ${'a'.uchr} ${(point){3, 4}} ${n.hex}`
    println(t.count, " ", t.bytes^.count)
    var u = $`${t}${s}`
    println(u.count == t.count + s.count)
    var h = $`plain`
    println(h, " ", h.typename)
    return 0
}
// out: Hello, Kelvin! 42 / 4.0 = 10.5 30 String
// out: 333 333
// out: true
// out: plain String
// c: kv_string s = ({ kv_string _kv_s = kv_string_new(); kv_string_append_text(&_kv_s, "Hello, "); kv_string_append_text(&_kv_s, name);
// c: kv_string_append_ref(&_kv_s, &(big));
// c: kv_string_append_uchr(&_kv_s, kv_uchr_of('a'));
