// an operator is a function (#471): c + c of an owner moved c out
// twice, and stopped at run time, index 0 out of range (#500)
struct Big { limbs: $[u64] }
extend Big {
    static let +(a:Self, b:Self):Self {
        var r:$[u64] = $[]
        r += a.limbs[0] + b.limbs[0]
        return (Self){r.copy()}
    }
}
let main():int32 {
    var x:$[u64] = $[]
    x += 1
    let c = (Big){x.copy()}
    let d = c + c
    println(d.limbs)
    return 0
}
// error: 'c' moves out twice in this expression, and the second takes what the first left, nothing: give one a copy made in a statement before, as 'let c2 = c.copy()'
