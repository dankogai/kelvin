// fallthrough (#386), Swift's: on into the next case's body, its label
// unchecked, from anywhere in the case, a loop or an if of it too; the
// owners of the case it leaves are freed; of the innermost switch
enum shape { none; circle: float64; rect: float64 }
let grade(n:int64):String {
    var s = $""
    switch n {
    case 3:
        s += "three "
        fallthrough
    case 2:
        let t = $"two "
        s += &t
        if n == 2 { fallthrough }
        s += "skip "
    case 1:
        s += "one "
        for i in 0..<3 {
            if i == 1 { fallthrough }
        }
    default:
        s += "any"
    }
    return s
}
let main():int32 {
    for n in 0...4 { println(grade(n)) }
    let sh = shape.circle(2.0)
    switch sh {
    case circle(r):                 // from a case that binds
        print(r, " ")
        fallthrough
    case none:
        println("round or none")
    case rect(q): println(q)
    }
    switch 1 {
    case 1:
        switch 2 {
        case 2: fallthrough
        default: print("inner ")
        }
        fallthrough
    default: println("outer")
    }
    return 0
}
// out: any
// out: one any
// out: two one any
// out: three two skip 
// out: any
// out: 2.0 round or none
// out: inner outer
// c: goto _kv_fall0;
// c: _kv_fall0:
