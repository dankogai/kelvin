// an attribute may be read, and a var attribute set, before it is
// written (#544), as a method may be called (#505): kelvinc writes its
// prototype, let T.x:R, where it is needed; of a struct and of a built-in
// type, at the top and in extend T { }. A function whose result is a
// Dictionary's type, ${K: V}, may be called before it is written too
struct p { x: i64; y: i64 }
struct name { s: String }
struct temp { c: f64 }
let main():int32 {
    let v:p = {3, 4}
    let n:i64 = 5
    var w:name = {$"ann"}
    println(v.sq, " ", v.sum, " ", v.both.sq, " ", n.half, " ", 2.5.twice, " ", w.loud, " ", v.table, " ", v.pair)
    var t:temp = {10.0}
    t.f = 212.0
    t.k += 1.0
    println(t.c, " ", t.f, " ", table_of(7))
    return 0
}
let p.sq:i64 { self.x * self.x }
extend p {
    let sum:i64 { self.x + self.y }
    let both:Self { (Self){self.sum, self.sq} }
    let table:${String: i64} { ${"x": self.x} }
    let pair:{a:i64, b:i64} { return {self.x, self.y} }
}
let i64.half:f64 { self as f64 / 2.0 }
extend f64 {
    let twice:f64 { self * 2.0 }
}
let name.loud:String {
    var t = self.s.copy()
    t += "!"
    return t
}
var temp.f:f64 {
    get { self.c * 9.0 / 5.0 + 32.0 }
    set(x) { self.c = (x - 32.0) * 5.0 / 9.0 }
}
extend temp {
    var k:f64 {
        get { self.c + 273.15 }
        set(x) { self.c = x - 273.15 }
    }
}
let table_of(n:i64):${String: i64} { ${"n": n} }
// out: 9 7 49 2.5 5.0 ann! {"x": 3} {a: 3, b: 4}
// out: 101.0 213.80000000000001 {"n": 7}
