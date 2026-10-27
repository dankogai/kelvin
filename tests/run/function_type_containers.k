// function types wherever a type goes (#403): an array of functions,
// fixed or an Array, a Dictionary of them, a dispatch table; a pointer to
// a function type, ((i64):i64)^, as kelvinc prints it; and typealias of a
// function type, which ^ may follow
typealias op = (i64):i64
let inc(n:i64):i64 { n + 1 }
let dbl(n:i64):i64 { n * 2 }
let apply(f:op, n:i64):i64 { return f(n) }
let pick(out:((i64):i64)^, k:i64):() { out^ := k == 0 ? inc : dbl }
let main():i32 {
    var fs:[op](2) = [inc, dbl]
    var gs = Array<op>()
    gs.append(inc)
    gs.append(dbl)
    var table = Dictionary<String, (i64):i64>()
    table["inc"] = inc
    table["dbl"] = dbl
    var f:op := inc
    pick(&f, 1)
    let pf:((i64):i64)^ := &f
    let qf := &f
    let ps:op^ := &f
    var hs = [((i64):i64)^](2)
    println(fs[1](5), " ", gs[0](5), " ", gs.count, " ", table["dbl"]!(21), " ", apply(dbl, 4), " ", f(10), " ", pf^(3), " ", hs[0].isNull)
    println(fs.typename, " ", gs.typename, " ", pf.typename, " ", qf.typename, " ", ps.typename, " ", f.typename, " ", hs.typename)
    for g in gs { print(g(1), " ") }
    println()
    return 0
}
// out: 10 6 2 42 8 20 6 true
// out: [(i64):i64](2) Array<(i64):i64> ((i64):i64)^ ((i64):i64)^ ((i64):i64)^ (i64):i64 [((i64):i64)^](2)
// out: 2 2 
// c: KV_ARRAY(__typeof__(int64_t (*)(int64_t)), _kv_array_Fi64Ei64, KV_PLAIN_FREE, KV_PLAIN_COPY)
// c: void pick(int64_t (**const out)(int64_t), const int64_t k)
