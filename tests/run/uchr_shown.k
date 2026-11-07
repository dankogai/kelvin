// a uchr inside a value (#479): uchr("x"), its character quoted as text
// is, so that it pastes back, U+0000 as uchr(0); in an Array, a
// Dictionary, an Optional, a struct and its fixed array, an enum's case;
// by print, .cstr, a template and .pretty; on its own, its character
struct glyph { c: uchr; n: i64; two: [uchr](2) }
enum mark { none; at: uchr; pair: {a: uchr, b: i64} }
let main():int32 {
    let a = $[uchr("x"), uchr("é"), uchr("\""), uchr("\n"), uchr(0), uchr("😀"), uchr("\\")]
    println(a)
    let back = $[uchr("x"), uchr("é"), uchr("\""), uchr("\n"), uchr(0), uchr("😀"), uchr("\\")]
    println(back == a, " ", a.map { $0.utf32 })
    let d = ${1: uchr("y")}
    let o:uchr? = uchr("z")
    println(d, " ", o, " ", `${o}`, " ", d.pretty)
    let g:glyph = {uchr("ω"), 2, [uchr("p"), uchr("\t")]}
    println(g, " ", g.cstr, " ", `<${g}>`)
    println(mark.at(uchr("m")), " ", mark.pair({uchr("é"), 3}))
    println(uchr("k"), " ", `${uchr("k")}`, " ", uchr("k").cstr)
    return 0
}
// out: [uchr("x"), uchr("é"), uchr("\""), uchr("\n"), uchr(0), uchr("😀"), uchr("\\")]
// out: true [120, 233, 34, 10, 0, 128512, 92]
// out: {1: uchr("y")} some(uchr("z")) some(uchr("z")) {
// out:   1: uchr("y")
// out: }
// out: {c: uchr("ω"), n: 2, two: [uchr("p"), uchr("\t")]} {c: uchr("ω"), n: 2, two: [uchr("p"), uchr("\t")]} <{c: uchr("ω"), n: 2, two: [uchr("p"), uchr("\t")]}>
// out: at(uchr("m")) pair({a: uchr("é"), b: 3})
// out: k k k
// c: kv_cstr_quoted_uchr(
