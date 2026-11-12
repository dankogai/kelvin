// &x.i64: x.i64 is i64(x), a conversion, a value with no address (#535);
// kelvinc and kc say so, where C did
let main():int32 {
    var x:i32 = 1
    let r := &x.i64
    return 0
}
// error: a conversion to i64 is a value, and has no address: '&' takes a variable, a member, an element or 'p^'; bind the value to a variable first
