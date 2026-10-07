// p++ and p-- step a var pointer, as statements (#51): a variable, a
// field, an element, a for clause, and a pointer only C sees
#import <stdlib.h> as C
struct node { v: i64; next: node^ }
struct cur { p: u8^ }
let main():i32 {
    let s:cstr := "hello"
    var p := s
    p++
    p++; p--
    var c:cur = {s}
    c.p++
    var n = 0
    for (var q := s; q^ != 0; q++) { n += 1 }
    var pp:[u8^](2) = [s, s]
    pp[1]++
    var e:cstr := getenv("HOME")
    e++
    println(p^, " ", c.p^, " ", n, " ", pp[1]^, " ", e.isNull)
    return 0
}
// out: 101 101 5 101 false
// c: p++;
// c: c.p++;
// c: q++)
