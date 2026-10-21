// error: an owner is not copied by '=' (#54): copy its bytes with 'v'.copy(), or borrow it with ':= &v'
let main():int32 {
    var a = ${"x": $"one"}
    var v = $"v"
    a["y"] ??= v
    return 0
}
