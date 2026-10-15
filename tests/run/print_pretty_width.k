// x.pretty(n) (#127): n spaces a level, an integer from 0 to 10, as JS
// clamps JSON.stringify's space; x.pretty stays two; 0 still breaks the
// lines; a computed width is clamped at run time; in print, f.println,
// templates, and as a String
#import <IO>
struct point { x: i64; y: i64 }
let main():i32 {
    var d = ${"a": $[1, 2]}
    let p:point = {1, 2}
    println(d.pretty(4))
    println(p.pretty(0))
    let w:i64 = 99
    var s = d.pretty(w)
    println(s.count, " ", s.typename)
    println(`t = ${p.pretty(3)}`)
    var u = $`u = ${p.pretty(1)}`
    println(u)
    IO.stdout.println(p.pretty(2) )
    return 0
}
// out: {
// out:     "a": [
// out:         1,
// out:         2
// out:     ]
// out: }
// out: {
// out: x: 1,
// out: y: 2
// out: }
// out: 77 String
// out: t = {
// out:    x: 1,
// out:    y: 2
// out: }
// out: u = {
// out:  x: 1,
// out:  y: 2
// out: }
// out: {
// out:   x: 1,
// out:   y: 2
// out: }
// c: .width = kv_out_width(w)
