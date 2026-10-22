// |= takes another Set in a variable, not a borrow of one: s |= &t, &= and
// ~= with it, crashed kelvinc, which read the name of a pointer type (#277)
let main():int32 {
    var s = ${1, 2}
    let t = ${3}
    s &= &t
    return 0
}
// error: '&=' takes another Set<i64>, in a variable
