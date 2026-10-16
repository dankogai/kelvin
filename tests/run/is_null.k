// p.isNull is p == nullptr, a bool, of every pointer and function value
// (#50); a field named isNull wins, and a value only C sees keeps its field
#import <stdlib.h> as C
struct node { v: int64; next: node^ }
struct odd { isNull: int64 }
let twice(n:int64):int64 { n * 2 }
let main():int32 {
    var p:int64^
    let n:node = {1, nullptr}
    var q := &n
    var f:(int64):int64
    let o:odd = {7}
    let env:cstr := getenv("KELVIN_NO_SUCH_VARIABLE")
    let s:cstr := "hi"
    let z = p.isNull
    println(p.isNull, " ", q.isNull, " ", q^.next.isNull, " ", f.isNull, " ", twice.isNull, " ", nullptr.isNull)
    println(s.isNull, " ", o.isNull, " ", env.isNull, " ", z, " ", z.typename)
    if p.isNull && !q.isNull { println("ok") }
    f := twice
    while !f.isNull { println(f(2)); f := nullptr }
    return 0
}
// out: true false true true false true
// out: false 7 true true bool
// out: ok
// out: 4
// c: ((bool)((p) == 0))
