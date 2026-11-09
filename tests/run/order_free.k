// a function, a method, an operator or a function of a type may be called
// before it is written, as in Swift and kc (#505): kelvinc writes its
// prototype where a declaration before it names it; C's function the
// program declares later, sin, is lifted beside it
#import <math.h> as C
struct W { n: u64 }
extend W {
    static let +(a:Self, b:Self):Self { W.of(a.n + b.n) }
    let twice():Self { self.half().scaled(4) }
    static let of(n:u64):Self { (Self){n} }
    let half():Self { (Self){self.n / 2} }
    let scaled(k:u64):Self { (Self){self.n * k} }
}
struct point { x: int32 }
struct Box { n: i64 }
extend Box {
    var put(s:const String^) { self.put(s^.cstr) }
    var put(s:cstr) { self.n += 1 }
}
let f(n:i64):i64 { g(n) + 1 }
let twice_all(xs:$[i64]):$[i64] { xs.map(doubled) }
let half_sin(x:float64):float64 { sin(x) / 2.0 }
let say(s:const String^) { say(s^.cstr) }
let main():int32 {
    let p:point = {3}
    var b:Box = {0}
    b.put(&$"one")
    b.put("two")
    say(&$"said")
    println(f(3), " ", (W.of(1) + W.of(2)).n, " ", W.of(8).twice().n, " ", p.area(), " ", b.n, " ", 後(1))
    println(twice_all($[1, 2, 3]), " ", half_sin(0.0))
    return 0
}
let g(n:i64):i64 { n * 2 }
let doubled(n:i64):i64 { n * 2 }
let point.area():int32 { return .x * .x }
let say(s:cstr) { println(s) }
let sin(x:float64):float64
let sin(p:point):point { (point){p.x} }
let 後(n:int64):int64 { n + 1 }
// out: said
// out: 7 3 16 9 2 2
// out: [2, 4, 6] 0.0
