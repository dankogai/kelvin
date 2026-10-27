// a struct, union or enum defined inside a function (#390): the block's,
// from its definition to the block's end, hiding a type of the top level
// of its name; a type of the top level in C, _kv_main_pair, written before
// the function; a C enum's enumerators the block's too
struct point { x:i64 }
let f():i64 {
    struct point { y:f64, z:f64 }
    let q:point = {1.5, 2.5}
    return i64(q.y + q.z)
}
let main():i32 {
    struct pair {
        enum kind { round; sides: i64 }
        a:i64
        k:kind
        next:pair^
    }
    union bits { i:i32, f:f32 }
    enum color { red, green = 5, blue }
    var p:pair = {3, pair.kind.sides(4), nullptr}
    var ps = Array<pair>()
    ps.append(p)
    let b:bits = {.i = 1}
    let c = green
    println(p, " ", p.typename, " ", p.k.typename, " ", ps.typename, " ", b, " ", c, " ", blue, " ", f())
    switch c {
    case red: println("red")
    case green: println("green")
    case blue: println("blue")
    }
    if true {
        struct pair { s:String }
        enum color { cyan, red }
        let w:pair = {String("inner")}
        let r = red
        println(w, " ", w.typename, " ", r)
    }
    let top:point = {7}
    let twice := { (n:i64):i64 in
        struct box { v:i64 }
        let x:box = {n * 2}
        return x.v
    }
    println(top, " ", red, " ", sizeof(pair), " ", twice(21))
    return 0
}
// out: {a: 3, k: sides(4), next: nullptr} pair pair.kind Array<pair> <union bits> 5 6 4
// out: green
// out: {s: "inner"} pair 1
// out: {x: 7} 0 32 42
// c: struct _kv_f_point
// c: struct _kv_main_pair__kind
// c: struct _kv_main_pair
// c: _kv_main_red,
// c: struct _kv_main_pair1
