// error: ')' closes nothing: no '(' is open here
// The ) too many of f is the error, not the method after it: the prototypes
// of #505 took twice() of extend pt { }, which the function twice(p) is
// called before, for a function of the top level, wrote its header before
// f, and 'Self' there had no type (#555).
struct pt { x: i64; y: i64 }
let twice(p:pt):pt { return (pt){p.x * 2, p.y * 2} }
let f(a:i64):i64 {
    let q = twice((pt){a, a})
    return (q.x + 1)) * 2
}
extend pt {
    let twice():Self { twice(self) }
}
let main():int32 {
    println(f(3))
    return 0
}
