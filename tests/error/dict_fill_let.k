// error: 'a' is a let and cannot change; declare it with var
let main():int32 {
    let a = ${"x": 1}
    var b = ${"x": 2}
    a ??= b
    return 0
}
