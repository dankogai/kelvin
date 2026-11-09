// an owner that moves out in an expression is named there once; the
// target of =, given anew, is not counted, and == wraps a copy of an
// owner to compare, which stays (#500)
struct bag { name: String; n: int64 }
let +(a:bag, b:bag):bag { (bag){a.name + b.name, a.n + b.n} }
let one(a:String):i64 { return a.count as i64 }
let both(a:String, b:String):i64 { return a.count as i64 + b.count as i64 }
let twice(a:String):String { return a + a }
let main():int32 {
    var s = $"ab"
    s = twice(s)
    let n = s.count as i64
    println(s, " ", n)
    println(n + one(s))
    var t = $"xyz"
    let u = t.copy()
    println(both(u, t))
    var z:bag = {$"z", 1}
    let w:bag = {$"w", 2}
    z += w.copy()
    z = z + w
    println(z.name, " ", z.n)
    let o:String? = $"hi"
    var h = $"hi"
    println(o == h, " ", o != h, " ", h)
    var p:bag = {$"hi", 3}
    println(o == p.name, " ", p.name)
    return 0
}
// out: abab 4
// out: 8
// out: 6
// out: zww 5
// out: true false hi
// out: true hi
