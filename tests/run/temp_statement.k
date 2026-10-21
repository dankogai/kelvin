// a pointer into an owner an expression gives keeps it alive until the call
// or expression around the pointer is done, up to the statement (#245):
// .cstr of a String an expression gives goes to C, and is freed after
// out: 3
// out: 42
// out: 6 long
// out: true 3 122
#import <string.h> as C

let first(s:cstr):uint8 { return s[0] }

let main():int32 {
    println(strlen($"abc".cstr))
    println(String(42).cstr)
    let n:size_t = strlen($"kelvin".cstr)
    if strlen(String(1234).cstr) > 3 { println(n, " long") }
    println(strcmp($"a".cstr, $"b".cstr) < 0, " ", strlen(String(7).cstr) + strlen($"xy".cstr), " ", first($"zebra".cstr))
    return $"zz".cstr[0] == 122 ? 0 : 1
}
