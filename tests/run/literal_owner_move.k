// a local owner named in a struct's literal moves into it, as into a
// call (#503): (Big){r, false}, {.name = t}, return {r} and a nested
// literal take it, without .copy(); it is dead until assigned anew
struct Big { limbs: $[u64]; neg: bool }
struct P { name: String; n: int64 }
struct H { p: P; k: int64 }
let mk(n:u64):Big {
    var r:$[u64] = $[]
    r += n
    return {.limbs = r, .neg = true}
}
let named(s:String):P { (P){s, 1} }
let main():int32 {
    var r:$[u64] = $[]
    r += 1
    let b = (Big){r, false}
    r = Array<u64>()
    r += 2
    let c:Big = {r, true}
    println(b.limbs, " ", c.limbs, " ", c.neg, " ", mk(7).limbs, " ", named($"x"))
    var s = $"in"
    let h:H = {{s, 1}, 2}
    var t = $"t"
    let q:P = {.n = 3, .name = t}
    var ps:$[P] = $[]
    var u = $"u"
    ps.append((P){u, 4})
    println(h, " ", q, " ", ps)
    t = $"again"
    println(t)
    return 0
}
// out: [1] [2] true [7] {name: "x", n: 1}
// out: {p: {name: "in", n: 1}, k: 2} {name: "t", n: 3} [{name: "u", n: 4}]
// out: again
// c: kv_string_take(&s)
