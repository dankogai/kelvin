// d[k] of a Dictionary of functions would be an Optional of a function
// (#764), which has no spelling yet; kc built it. for k, f in d walks them
let twice(x:int64):int64 { x * 2 }
let main():int32 {
    var d:${String: (int64):int64} = ${"a": twice}
    if let f = d["a"] { println(f(2)) }
    return 0
}
// error: an Optional of a function type has no spelling yet
