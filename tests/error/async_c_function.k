// async runs a function whose types kelvinc sees (#312), not C's
let main():int32 {
    let t = async puts("x")
    return 0
}
// error: 'async' takes a call of a Kelvin function or a function value, whose types kelvinc sees, as in 'async f(x)'
