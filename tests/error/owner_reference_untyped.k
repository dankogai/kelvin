// := of an owner's variable, no type written, is an owner not copied
// (#789), as kelvinc says it first: kc said 'b' is a value
let main():int32 {
    var a:$[int64] = $[1]
    var b := a
    return 0
}
// error: an owner is not copied by '=' (#54): copy its bytes with 'a'.copy(), or borrow it with ':= &a'
