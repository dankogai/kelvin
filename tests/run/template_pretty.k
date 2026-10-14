// ${v.pretty} in a template (#126): the value's text indented, by
// kelvinc's printer, as print shows .pretty; in a template's room it is
// cut as a string value is, and in $`...` it is whole
struct point { x: i64; y: i64 }
let main():i32 {
    var d = ${"a": $[1, 2]}
    let p:point = {1, 2}
    let t := `d = ${d.pretty}`
    println(t)
    var u = $`p = ${p.pretty}, then ${d}`
    println(u)
    var o:point? = {3, 4}
    println(`${o.pretty}`)
    return 0
}
// out: d = {
// out:   "a": [
// out:     1,
// out:     2
// out:   ]
// out: }
// out: p = {
// out:   x: 1,
// out:   y: 2
// out: }, then {"a": [1, 2]}
// out: some({
// out:   x: 3,
// out:   y: 4
// out: })
