// ${xs} of an Array, a Dictionary or a Set in a template (#125): its text
// as print shows it (#123), Strings inside quoted; in a template's room it
// is cut as a string value is, past KV_TEMPLATE_STR bytes, and in $`...`
// it is whole
let main():int32 {
    var xs = $[1, 2, 3]
    var names = $[$"ann", $"b\"c"]
    var d = ${"k": $[1]}
    var s = ${3, 1}
    var empty:$[int64] = $[]
    let t := `xs = ${xs}, names = ${names}, d = ${d}, s = ${s}, empty = ${empty}`
    println(t)
    var u = $`whole: ${xs} ${d} ${s}`
    println(u, " ", u.count, " ", u.typename)
    var big = Array<int64>()
    for i in 0..<200 { big += i }
    let cut := `${big}`
    var all = $`${big}`
    println(cut.count, " ", all.count)
    return 0
}
// out: xs = [1, 2, 3], names = ["ann", "b\"c"], d = {"k": [1]}, s = {3, 1}, empty = []
// out: whole: [1, 2, 3] {"k": [1]} {3, 1} 34 String
// out: 256 890
