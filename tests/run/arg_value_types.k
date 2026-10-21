// an argument is checked against its parameter's type (#257), once
// converted and lent, as a declaration's value is (#255): a number takes
// any number, a String a String or text, an Optional its T or none, a
// borrow a pointer or an owner an expression gives, lent
// out: 5.0 hi some(3) none 2
// out: 8 {x: 3}
struct pt { x: int64 }
extend pt {
    let moved(dx:int64):pt { (pt){self.x + dx} }
}
let half(x:float64):float64 { x / 2 }
let greet(s:String):String { s }
let maybe(o:int64?):int64? { o }
let size(s:const String^):int64 { s^.count as int64 }

let main():int32 {
    println(half(10), " ", greet("hi"), " ", maybe(3), " ", maybe(none), " ", size($"ab"))
    let p = (pt){1}
    let s = $"eightchr"
    println(size(&s), " ", p.moved(2))
    return 0
}
