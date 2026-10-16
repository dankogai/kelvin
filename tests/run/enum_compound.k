// x += y on an enum with values, by the operator the program defines
// (#128): x = x + y, as for a struct (#42); for one that owns, x is read
// before what it held is freed, so x = x + y and x = f(x) keep its value
enum maybe { none; some: int64 }
let +(a:maybe, b:maybe):maybe {
    if a.is(some) && b.is(some) { return {.some = a.some + b.some} }
    return {.none}
}
let -(a:maybe, b:maybe):maybe {
    if a.is(some) && b.is(some) { return {.some = a.some - b.some} }
    return {.none}
}
enum txt { none; s: String }
let +(a:txt, b:txt):txt {
    if a.is(s) && b.is(s) {
        var r = a.s.copy()
        r += &b.s
        return txt.s(r)
    }
    return {.none}
}
let shout(t:txt):txt {
    if let s(v) = t {
        var r = v.copy()
        r += "!"
        return txt.s(r)
    }
    return {.none}
}
struct bag { name: String; n: int64 }
let +(a:bag, b:bag):bag {
    var c = a.name.copy()
    c += &b.name
    return {.name = String(c.cstr), .n = a.n + b.n}
}
let main():int32 {
    var x = maybe.some(1)
    x += maybe.some(2)
    x -= maybe.some(10)
    println(x, " ", x.typename)
    x += maybe.none
    println(x)
    var t = txt.s($"ab")
    t += txt.s($"cd")
    println(t)
    t = t + txt.s($"ef")
    t = shout(t)
    println(t)
    var b:bag = {$"x", 1}
    var y:bag = {$"y", 2}
    b += y
    println(b)
    return 0
}
// out: some(-7) maybe
// out: none
// out: s("abcd")
// out: s("abcdef!")
// out: {name: "xy", n: 3}
// c: _kv_txt_assign(&t, _kv_add_op__txt__txt(_kv_txt_take(&t),
