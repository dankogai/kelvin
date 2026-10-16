// ?? reads its left side twice, so it is a place (#72)
let f():int64? { return 1 }
let main():int32 {
    var y = f() ?? 1
    return 0
}
// error: '??' reads its left side twice: bind it to a variable first
