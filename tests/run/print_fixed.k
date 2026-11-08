// a fixed array is shown as [a, b] (#481), as inside a struct, so that it
// pastes back: by print, a template, $`...` and .pretty; of numbers,
// uchrs, structs, Optionals, text, rows and a variable length; a let
// array parameter by its declared length; a [u8](N) is still text
struct P { x: i32; two: [i32](2) }
let show(xs:[i64](3)) {
    println(xs, " ", `${xs}`)
}
let main():int32 {
    var f = [i32](2)
    f[0] = 5
    let p:P = {1, [2, 3]}
    println(f, " ", p, " ", p.two)
    let back:[i32](2) = [5, 0]
    println(back[0] == f[0] && back[1] == f[1])
    let t:cstr := `<${f}>`
    let s = $`<${f}>`
    println(t, " ", s)
    var u = [uchr](2)
    u[0] = uchr("é")
    var m = [[i32](3)](2)
    m[1][2] = 9
    var ps = [P](1)
    var o = [i32?](2)
    o[1] = 4
    var c = [cstr](2)
    c[0] := "hi"
    var b = [u8](4)
    b[0] = 65
    println(u, " ", m, " ", ps, " ", o, " ", c, " ", b)
    println(f.pretty)
    show(([i64])[1, 2, 3])
    let n = 3
    var v = [f64](n)
    v[2] = 2.5
    println(v)
    return 0
}
// out: [5, 0] {x: 1, two: [2, 3]} [2, 3]
// out: true
// out: <[5, 0]> <[5, 0]>
// out: [uchr("é"), uchr(0)] [[0, 0, 0], [0, 0, 9]] [{x: 0, two: [0, 0]}] [none, some(4)] ["hi", nowhere] A
// out: [
// out:   5,
// out:   0
// out: ]
// out: [1, 2, 3] [1, 2, 3]
// out: [0.0, 0.0, 2.5]
// c: _kv_show_fixed_int32_t(
