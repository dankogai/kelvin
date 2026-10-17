// methods of one name overloaded by their parameter types (#158), chosen
// by the arguments as functions are (#41), an anonymous argument taking
// the type of the overload that has a function there; an owner given by
// value moves into a method, and into a call through a function value
struct box { v: String }
extend box {
    let add(n:int64):int64 { .v.count as int64 + n }
    let add(t:cstr):int64 { .v.count as int64 + t.count as int64 }
    let add(f:(int64):int64):int64 { f(.v.count as int64) }
    let add(other:box):int64 { .v.count as int64 + other.v.count as int64 }   // other moves in, and is freed here
    let twice(f:(box):String):String { f(.copy()) }
}
let make(t:cstr):box { var b:box = {.v = String(t)}; return b }
let through(b:box, f:(box):int64):int64 { f(b) }   // b moves into f
let main():int32 {
    var b = make("abc")
    var c = make("xy")
    println(b.add(1), " ", b.add("wxyz"), " ", b.add() { $0 * 10 }, " ", b.add(c))
    var d = b.twice() { $`${$0.v}!` }
    println(d)
    println(through(make("four")) { $0.v.count as int64 }, " ", through(b) { $0.v.count as int64 + 100 })
    var n = String(42)
    var f = String(2.5 * 2.0)
    var t = String(true)
    println(n, " ", f, " ", t, " ", n.count)
    return 0
}
// out: 4 7 30 5
// out: abc!
// out: 4 103
// out: 42 5 true 2
