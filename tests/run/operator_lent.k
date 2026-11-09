// an operator is lent an owner operand, which its caller keeps (#501):
// a == b, a * a + b, c + c, z += z and h.b + c leave their operands,
// where #471 moved them in; one an expression gives is held and freed
// after; a var parameter is given a copy of its own
struct Big { limbs: $[u64] }
extend Big {
    static let +(a:Self, b:Self):Self {
        var r:$[u64] = $[]
        r += a.limbs[0] + b.limbs[0]
        return (Self){r.copy()}
    }
    static let *(a:Self, b:Self):Self {
        var r:$[u64] = $[]
        r += a.limbs[0] * b.limbs[0]
        return (Self){r.copy()}
    }
    static let -(var a:Self, b:Self):Self {
        a.limbs[0] -= b.limbs[0]
        return a
    }
    static let ==(a:Self, b:Self):bool { a.limbs[0] == b.limbs[0] }
}
let big(n:u64):Big {
    var r:$[u64] = $[]
    r += n
    return (Big){r.copy()}
}
struct holder { b: Big; k: int64 }
let g = big(100)
let main():int32 {
    let a = big(3)
    let b = big(4)
    let c = a * a + b
    let d = c + c
    println(a.limbs, " ", b.limbs, " ", c.limbs, " ", d.limbs, " ", a == b, " ", a == big(3))
    var z = big(1)
    z += z
    z = z * a
    z -= big(1)
    println(z.limbs, " ", (big(10) - a).limbs, " ", (a - a).limbs, " ", a.limbs, " ", (big(2) + big(5)).limbs)
    var h:holder = {big(7), 2}
    println((h.b + a).limbs, " ", h.b.limbs, " ", (g + g).limbs, " ", g.limbs)
    var xs:$[Big] = $[]
    xs.append(big(5))
    xs.append(big(6))
    var sum = big(0)
    for x in xs { sum = sum + x }
    println(sum.limbs, " ", (xs[0] * xs[1]).limbs, " ", xs.count)
    return 0
}
// out: [3] [4] [13] [26] false true
// out: [5] [7] [0] [3] [7]
// out: [10] [7] [200] [100]
// out: [11] [30] 2
