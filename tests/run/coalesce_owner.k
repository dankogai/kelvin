// x ?? y of an Optional or a Result whose value owns (#250): x is read
// once; its value is a copy where x is a place, else taken out of it, and
// the rest of it, an err's value, freed; y a copy where it is a place,
// else taken, and made only where x has no value. What ?? gives is an
// owner that an expression gives, bound or freed as one
// out: ann none bob
// out: held fallback some("held") fallback
// out: one x one y
// out: given default held 1
// out: [1, 2] [0]
// out: recovered
// out: r q
let find(d:Dictionary<int64, String>^, v:int64):String? { return d^[v] }
let pick(o:String?):String { return o ?? $"default" }   // a parameter that owns is a place: a copy, freed with it

let main():int32 {
    var a = ${"ann": 31, "bob": 42}
    println(a.lastKey(31) ?? $"none", " ", a.lastKey(7) ?? $"none", " ", a.firstKey(42) ?? "text")
    var o:String? = $"held"
    var p:String? = none
    let fb = $"fallback"
    let s = o ?? fb
    let t = p ?? fb
    println(s, " ", t, " ", o, " ", fb)
    var d = ${1: $"one"}
    println(d[1] ?? $"x", " ", d[2] ?? $"x", " ", find(&d, 1) ?? $"y", " ", find(&d, 3) ?? $"y")
    println(pick($"given"), " ", pick(none), " ", p ?? (o ?? $"z"), " ", (p ?? $"w").count)
    var xs:Array<int64>? = $[1, 2]
    var ys:Array<int64>? = none
    println(xs ?? $[0], " ", ys ?? $[0])
    var r:Result<String, String> = Result<String, String>.err($"bad")
    println(r ?? $"recovered")
    var n:Array<String?> = $[$"q", none]
    println(n[1] ?? $"r", " ", n[0] ?? $"r")
    return 0
}
