// a template shows a struct by its .cstr, and a value that is already
// one, p.cstr, as it is, not as p.cstr.cstr, which crashed kelvinc; a
// property that gives a struct, f.stat (#104), is still a struct
#import <IO>
struct point { x: int64; y: int64 }
struct line { a: point; b: point }
let mid(l:line):point { return {(l.a.x + l.b.x) / 2, (l.a.y + l.b.y) / 2} }
let main():int32 {
    var l:line = {{0, 0}, {4, 6}}
    let q:point^ := &l.b
    println(`${l.a.cstr} ${q^.cstr} ${mid(l).cstr} ${l.cstr}`)
    println(`${l.a} ${q^} ${mid(l)} ${l}`)
    var s = $`${l.a.cstr}|${q^.cstr}|${mid(l).cstr}|${l.cstr}`
    println(s)
    var f = IO.stdout
    var t = $`${f.stat}`
    println(`${f.stat.cstr}`.count > 10, " ", t.count > 10)
    return 0
}
// out: {x: 0, y: 0} {x: 4, y: 6} {x: 2, y: 3} {a: {x: 0, y: 0}, b: {x: 4, y: 6}}
// out: {x: 0, y: 0} {x: 4, y: 6} {x: 2, y: 3} {a: {x: 0, y: 0}, b: {x: 4, y: 6}}
// out: {x: 0, y: 0}|{x: 4, y: 6}|{x: 2, y: 3}|{a: {x: 0, y: 0}, b: {x: 4, y: 6}}
// out: true true
