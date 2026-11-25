// Set with no <T> is no expression (#764): Set([q[0]]) has no element
// type written, and kelvinc reads the word alone
let main():int32 {
    var q:[int64](2) = [1, 2]
    var s := Set([q[0]])
    return 0
}
// error: expected an expression, found 'Set'
