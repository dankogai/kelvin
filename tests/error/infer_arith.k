// arithmetic has C's promoted type, which is not inferred (#47): `small +
// 1` would be an i32, not an i8
let main():int32 {
    var small:int8 = 1
    var next = small + 1
    return 0
}
// error: 'next' needs a type: write 'next:T = ...'
