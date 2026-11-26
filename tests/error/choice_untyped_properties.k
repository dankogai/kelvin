// a choice of two properties, no type written (#781): a property is
// no value kelvinc types in a choice, as a struct's member is; kc
// built it
let main():int32 {
    var a:$[int64] = $[1, 2]
    var q = true ? a.count : a.count
    return 0
}
// error: 'q' needs a type: write 'q:T = ...' (or 'q:T := ...' for a reference)
