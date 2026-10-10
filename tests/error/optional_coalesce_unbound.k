// ?? reads its left side twice, so it is a place (#72)
let f():i64? { return 1 }
let main():i32 {
    var y = f() ?? 1
    return 0
}
// error: '??' reads its left side twice: bind it to a variable first
