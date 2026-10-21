// error: this function names 1 parameter, and it is called with 2
let main():int32 {
    var a = ${"x": 1}
    var b = ${"x": 2}
    a.merge(&b) { p in p }
    return 0
}
