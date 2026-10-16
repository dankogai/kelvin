// :() after the parameters says a function gives nothing, C's void,
// written out (#141): on a function, a prototype, a method, an
// anonymous function and in a function type
struct point { x: int64; y: int64 }
let greet(name:cstr):() { println("hi ", name) }
let later():()                                            // a prototype
let point.show():() { println(self) }
let twice(f:(int64):(), n:int64):() { f(n); f(n) }
let later():() { println("later") }
let main():int32 {
    greet("kelvin")
    let p:point = {1, 2}
    p.show()
    let k:(int64):() := { (n:int64):() in println(n) }
    twice(k, 2)
    var g:(cstr):() := greet
    g("again")
    later()
    return 0
}
// out: hi kelvin
// out: {x: 1, y: 2}
// out: 2
// out: 2
// out: hi again
// out: later
// c: void greet(const uint8_t *const name)
// c: void twice(void (*const f)(int64_t), const int64_t n)
