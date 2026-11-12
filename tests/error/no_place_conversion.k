// b.i64 of a bool is i64(b), a conversion, a value: it is no place an
// assignment sets (#534); kelvinc and kc say so, where C did
let main():int32 {
    var b = true
    b.i64 = 1
    return 0
}
// error: a conversion to i64 is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
