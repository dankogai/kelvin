// cstr is immutable text (#52): a string literal, a text property and a
// template are cstr; .count is strlen, measured once and kept; a u8^ may
// take a cstr, with the cast written by kelvinc, but not the other way
#import <stdlib.h> as C
#import <string.h> as C
let shout(var p:u8^) { p[0] = 'U' }
let len(s:cstr):i64 { var n = 0; for i in 0..<s.count { n += 1 }; return n + i64(s.count) }
let main(argc:i32, argv:[cstr]):i32 {
    var s:cstr := "I love to hate C"
    let n = s.count
    var t:[u8](32)
    strcpy(t, s)
    t[0] = 'U'
    var p:u8^ := s                 // allowed, not encouraged: writing through p is C's undefined behavior
    shout(t)
    let first = s[0]
    s := "short"
    let m = s.count
    let lit := "abc"
    let env:cstr := getenv("NO_SUCH_KELVIN_VAR")
    let z := s.cstr
    let w := `${s}!`
    for c in s { print(c, " ") }
    println()
    println(n, " ", m, " ", t, " ", first, " ", s.typename, " ", lit.typename, " ", z.typename)
    println(w.typename, " ", p.typename, " ", env.isNull, " ", len(argv[0]) > 0, " ", s[s.count - 1], " ", w.count)
    return 0
}
// out: 115 104 111 114 116 
// out: 16 5 U love to hate C 73 cstr cstr cstr
// out: cstr u8^ true true 116 6
// c: const uint8_t *s = "I love to hate C";
// c: size_t _kv_s_count = (size_t)-1;
// c: uint8_t *p = (uint8_t *)s;
// c: _kv_s_count = (size_t)-1;
// c: strlen((const char *)s)
