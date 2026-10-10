// two loop variables walk a Dictionary, not an Array (#65)
let main():i32 {
    var xs = $[1, 2]
    for k, v in xs { }
    return 0
}
// error: two loop variables walk a Dictionary's entries, 'for k, v in d', and this is Array<i64>
