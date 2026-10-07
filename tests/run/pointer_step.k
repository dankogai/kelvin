// p++ and p-- step a var pointer, as statements (#51): a variable, a
// field, an element, a for clause, and a pointer only C sees
#import <stdlib.h> as C
struct node { v: i64; next: node^ }
struct cur { p: u8^ }
let main():i32 {
    let s:cstr := "hello"
    var p:u8^ := s                  // a cstr does not step: a u8^ cursor does (#52)
    p++
    p++; p--
    var c:cur = {s}
    c.p++
    var n = 0
    for (var q:u8^ := s; q^ != 0; q++) { n += 1 }
    var pp:[u8^](2) = [s, s]
    pp[1]++
    var e:u8^ := getenv("HOME")      // a cstr would not step (#52)
    e++
    println(p^, " ", c.p^, " ", n, " ", pp[1]^, " ", e.isNull)
    return 0
}
// out: 101 101 5 101 false
// c: p++;
// c: c.p++;
// c: q++)
