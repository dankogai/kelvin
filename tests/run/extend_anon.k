// extend of a type with no tag (#130), by its spelling, as #121's methods:
// a method, an attribute and a var attribute; its cases are words (#120)
enum { nothing; just: int64 }
extend enum{nothing, just: int64} {
    let orZero():int64 { .is(just) ? .just : 0 }
    let isJust:bool { .is(just) }
    var value:int64 {
        get { .orZero() }
        set(v) { self = just(v) }
    }
}
let main():int32 {
    var a = just(3)
    var b = nothing
    println(a.orZero(), " ", b.orZero(), " ", a.isJust, " ", b.isJust)
    b.value = 7
    b.value += 1
    println(b, " ", b.value)
    return 0
}
// out: 3 0 true false
// out: just(8) 8
