// error: 'a' is a let and cannot change; declare it with var, or write '.merging(...)'
let main():int32 {
    let a = ${"x": 1}
    var b = ${"x": 2}
    a.merge(&b)
    return 0
}
