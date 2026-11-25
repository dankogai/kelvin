// a function of rows of three, by its name, goes where a function of
// rows of a count C computes goes (#748), as an anonymous function of
// them does (#744); and a function value of its very type goes
// wherever one goes: an argument, a variable, a member, a result
struct ops { f:(int64):int64, n:int64 }
let apply(n:int64, f:([[int64](n)](2)):int64):int64 {
    var m:[[int64](3)](2) = [[1, 2, 3], [4, 5, 6]]
    return f(m)
}
let corners(m:[[int64](3)](2)):int64 { m[0][0] + m[1][2] }
let num(f:(int64):int64):int64 { f(1) }
let twice(x:int64):int64 { x * 2 }
let pick():(int64):int64 {
    return twice
}
let main():int32 {
    println(apply(3, corners))
    var g:(int64):int64 := twice
    g := { (x:int64):int64 in x + 10 }
    var o:ops = {{ (x:int64):int64 in x + 2 }, 1}
    var p:ops = {twice, 1}
    println(num(g), " ", o.f(1), " ", p.f(4), " ", pick()(5), " ", num(nowhere == g ? twice : g))
    return 0
}
// out: 7
// out: 11 3 8 10 11
