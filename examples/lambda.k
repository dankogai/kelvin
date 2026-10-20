// The untyped lambda calculus, written with λ: λx.M is a function of x,
// M N applies M to N, left to right, and a λ's body reaches as far right
// as it can, so λx.λy.x y is λx.(λy.(x y)). λx y.M is λx.λy.M. A number
// is its Church numeral, and a name in capitals one of the definitions
// below, of Wikipedia's article. A term is reduced in normal order, the
// leftmost-outermost redex first, (λx.M) N to M with N for x, until no
// redex is left or a limit of steps is reached.
// Inside, a variable is a de Bruijn index, how many λs out its own is,
// so a substitution never captures a name; the names come back when a
// term is shown, a binder renamed with a ′ where it would capture one.
// Terms are nodes of one Array by index, as in examples/ski.k.
//   kelvinc --run examples/lambda.k                     the examples below
//   kelvinc --run examples/lambda.k -- 'PLUS 2 3'       a term of your own
struct node {
    kind: uint8          // 'v' a bound variable, 'f' a free one, 'l' a λ, 'a' an application
    n: int64             // 'v': its index; 'f': its name; 'l': its binder's name
    a: int64             // 'l': its body; 'a': the function
    b: int64             // 'a': the argument
}

var pool:$[node]         // every node, by index
var names:$[String]      // every name, by number
var defs:$[int64]        // the definitions: a name, then its term, and so on

let make(kind:uint8, n:int64, a:int64, b:int64):int64 {
    let x:node = {kind, n, a, b}
    pool += x
    return pool.count as int64 - 1
}
let bound(i:int64):int64 { make('v', i, -1, -1) }
let lam(name:int64, body:int64):int64 { make('l', name, body, -1) }
let app(f:int64, x:int64):int64 { make('a', 0, f, x) }

// the number of a name, which is kept the first time it is seen
let intern(s:String^):int64 {
    for i in 0..<names.count as int64 {
        if names[i] == s^ { return i }
    }
    names += s^.copy()
    return names.count as int64 - 1
}

// ---------- reading ----------

let lambda_sign:uint32 = 0x3BB   // λ

let is_name(c:uint32):bool {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '\'' ||
        (c > 127 && c != lambda_sign && c != 0x2032)
}

// the Church numeral of k: λf.λx.f (f ... (f x))
let numeral(k:int64):int64 {
    var f = $"f"
    var x = $"x"
    var body = bound(0)
    for i in 0..<k { body = app(bound(1), body) }
    return lam(intern(&f), lam(intern(&x), body))
}

struct reader {
    codes: $[uint32]     // the codepoints of the text
    at: int64            // the next one
    scope: $[int64]      // the names of the λs around, the innermost last
    bad: bool            // whether something was not understood
}

let term(r:reader^):int64       // a prototype: the readers call each other

let peek(r:reader^):uint32 {
    while r^.at < r^.codes.count as int64 && r^.codes[r^.at] == ' ' { r^.at += 1 }
    return r^.at < r^.codes.count as int64 ? r^.codes[r^.at] : 0
}

// a name or a number at r^.at, as its text
let word(r:reader^):String {
    var s = $""
    while r^.at < r^.codes.count as int64 && is_name(r^.codes[r^.at]) {
        s += r^.codes[r^.at].uchr
        r^.at += 1
    }
    return s
}

// λ names . term, its λ read
let abstraction(r:reader^):int64 {
    var binders:$[int64] = $[]
    while peek(r) != '.' && peek(r) != 0 && is_name(peek(r)) {
        var w = word(r)
        binders += intern(&w)
    }
    if peek(r) != '.' || binders.count == 0 {
        r^.bad = true
        return -1
    }
    r^.at += 1
    for b in binders { r^.scope += b }
    var t = term(r)
    let n = binders.count as int64
    for i in 0..<n {
        r^.scope.pop()
        if t >= 0 { t = lam(binders[n - 1 - i], t) }
    }
    return t
}

// a variable, a number, a definition's name, or a term in parentheses
let atom(r:reader^):int64 {
    let c = peek(r)
    if c == '(' {
        r^.at += 1
        let t = term(r)
        if peek(r) != ')' {
            r^.bad = true
            return -1
        }
        r^.at += 1
        return t
    }
    var w = word(r)
    if w.count == 0 {
        r^.bad = true
        return -1
    }
    if c >= '0' && c <= '9' { return numeral(w.cstr.i64) }
    let id = intern(&w)
    let depth = r^.scope.count as int64
    for i in 0..<depth {                        // the innermost λ of that name
        if r^.scope[depth - 1 - i] == id { return bound(i) }
    }
    for i in 0..<defs.count as int64 / 2 {
        if defs[2 * i] == id { return defs[2 * i + 1] }   // closed, so it fits anywhere
    }
    return make('f', id, -1, -1)
}

// an application of one or more atoms, left to right; a λ takes the rest
let term(r:reader^):int64 {
    var t:int64 = -1
    while true {
        let c = peek(r)
        if c == 0 || c == ')' || r^.bad { return t }
        var x:int64 = -1
        if c == lambda_sign {
            r^.at += 1
            x = abstraction(r)
        } else {
            x = atom(r)
        }
        if x < 0 { return -1 }
        t = t < 0 ? x : app(t, x)
    }
}

// the term of a text, or -1 where it is none
let parse(text:cstr):int64 {
    var s = String(text)
    var r:reader = {$[], 0, $[], false}
    for c in s { r.codes += c.utf32 }
    let t = term(&r)
    return r.bad || r.at < r.codes.count as int64 ? -1 : t
}

let define(name:cstr, text:cstr):() {
    var s = String(name)
    let t = parse(text)
    if t < 0 { println("cannot read the definition of ", name) }
    defs += intern(&s)
    defs += t
}

// ---------- reducing ----------

// t with each variable that is free beyond cutoff λs moved by d
let shift(t:int64, d:int64, cutoff:int64):int64 {
    let x = pool[t]
    if x.kind == 'v' { return x.n >= cutoff ? bound(x.n + d) : t }
    if x.kind == 'l' { return lam(x.n, shift(x.a, d, cutoff + 1)) }
    if x.kind == 'a' { return app(shift(x.a, d, cutoff), shift(x.b, d, cutoff)) }
    return t
}

// t with s for the variable of index j
let subst(t:int64, j:int64, s:int64):int64 {
    let x = pool[t]
    if x.kind == 'v' { return x.n == j ? s : t }
    if x.kind == 'l' { return lam(x.n, subst(x.a, j + 1, shift(s, 1, 0))) }
    if x.kind == 'a' { return app(subst(x.a, j, s), subst(x.b, j, s)) }
    return t
}

// one step in normal order, or -1 where t is normal
let step(t:int64):int64 {
    let x = pool[t]
    if x.kind == 'a' {
        if pool[x.a].kind == 'l' {              // (λ.M) N: M with N for its variable
            return shift(subst(pool[x.a].a, 0, shift(x.b, 1, 0)), -1, 0)
        }
        let f = step(x.a)
        if f >= 0 { return app(f, x.b) }
        let b = step(x.b)
        return b >= 0 ? app(x.a, b) : -1
    }
    if x.kind == 'l' {
        let body = step(x.a)
        return body >= 0 ? lam(x.n, body) : -1
    }
    return -1
}

let limit:int64 = 10000

// t's normal form, or -1 where there is none within limit steps
let normal(t:int64):int64 {
    var u = t
    for i in 0..<limit {
        let next = step(u)
        if next < 0 { return u }
        u = next
    }
    return -1
}

// ---------- showing ----------

// whether the name n is that of a free variable in t
let free_in(t:int64, n:int64):bool {
    let x = pool[t]
    if x.kind == 'f' { return x.n == n }
    if x.kind == 'l' { return free_in(x.a, n) }
    if x.kind == 'a' { return free_in(x.a, n) || free_in(x.b, n) }
    return false
}

// the text of t, the names of the λs around it in scope, the innermost
// last; where is 0 for a whole term, 1 for a function, 2 for an argument
let show(t:int64, scope:$[int64]^, where:int64, all:int64):String {
    let x = pool[t]
    if x.kind == 'v' { return names[scope^[scope^.count as int64 - 1 - x.n]].copy() }
    if x.kind == 'f' { return names[x.n].copy() }
    if x.kind == 'a' {
        var s = show(x.a, scope, 1, all) + " " + show(x.b, scope, 2, all)
        return where == 2 ? $"(" + s + ")" : s
    }
    // a λ: its own name, primed while that would capture or hide one
    var name = names[x.n].copy()
    while true {
        let id = intern(&name)
        var taken = free_in(all, id)
        for s in scope^ {
            if s == id { taken = true }
        }
        if !taken { break }
        name += 0x2032.uchr                     // ′
    }
    scope^ += intern(&name)
    var s = $"λ" + name + "." + show(x.a, scope, 0, all)
    scope^.pop()
    return where == 0 ? s : $"(" + s + ")"
}

let text(t:int64):String {
    var scope:$[int64] = $[]
    return show(t, &scope, 0, t)
}

// the number of a Church numeral, or -1
let number(t:int64):int64 {
    if pool[t].kind != 'l' || pool[pool[t].a].kind != 'l' { return -1 }
    var u = pool[pool[t].a].a
    var k:int64 = 0
    while pool[u].kind == 'a' && pool[pool[u].a].kind == 'v' && pool[pool[u].a].n == 1 {
        k += 1
        u = pool[u].b
    }
    return pool[u].kind == 'v' && pool[u].n == 0 ? k : -1
}

// TRUE, FALSE, or "" where t is neither
let truth(t:int64):cstr {
    if pool[t].kind != 'l' || pool[pool[t].a].kind != 'l' || pool[pool[pool[t].a].a].kind != 'v' { return "" }
    return pool[pool[pool[t].a].a].n == 1 ? "TRUE" : "FALSE"
}

// ---------- the examples ----------

// the text, its normal form, and, as read asks, the number or the truth it is
let run(src:cstr, read:uint8):() {
    let t = parse(src)
    if t < 0 {
        var backslash = false
        for c in src {
            if c == '\\' { backslash = true }
        }
        println(src, backslash ? ": cannot read it: λ is written λ, not \\" : ": cannot read it")
        return
    }
    let u = normal(t)
    if u < 0 {
        println(src, " has no normal form within ", limit, " steps")
    } else if read == 'n' && number(u) >= 0 {
        println(src, " = ", number(u))
    } else if read == 'b' && truth(u)[0] != 0 {
        println(src, " = ", truth(u))
    } else {
        println(src, " = ", text(u))
    }
}

let main(argc:int32, argv:[cstr]):int32 {
    define("I", "λx.x")
    define("K", "λx y.x")
    define("S", "λx y z.x z (y z)")
    define("TRUE", "λx y.x")
    define("FALSE", "λx y.y")
    define("AND", "λp q.p q p")
    define("OR", "λp q.p p q")
    define("NOT", "λp.p FALSE TRUE")
    define("SUCC", "λn f x.f (n f x)")
    define("PLUS", "λm n f x.m f (n f x)")
    define("MULT", "λm n f.m (n f)")
    define("POW", "λb e.e b")
    define("PRED", "λn f x.n (λg h.h (g f)) (λu.x) (λu.u)")
    define("SUB", "λm n.n PRED m")
    define("ISZERO", "λn.n (λx.FALSE) TRUE")
    define("Y", "λf.(λx.f (x x)) (λx.f (x x))")
    define("FACT", "Y (λr n.ISZERO n 1 (MULT n (r (PRED n))))")
    if argc > 1 {
        run(argv[1], ' ')
        return 0
    }
    run("SUCC 1", ' ')
    run("PLUS 2 3", 'n')
    run("MULT 2 3", 'n')
    run("POW 2 3", 'n')
    run("PRED 3", 'n')
    run("SUB 5 2", 'n')
    run("FACT 3", 'n')
    run("AND TRUE FALSE", 'b')
    run("OR FALSE TRUE", 'b')
    run("NOT (ISZERO 0)", 'b')
    run("S K K a", ' ')
    run("(λx y.x y) y", ' ')                   // the y that comes in stays free
    run("(λx.x x) (λx.x x)", ' ')
    return 0
}
// out: SUCC 1 = λf.λx.f (f x)
// out: PLUS 2 3 = 5
// out: MULT 2 3 = 6
// out: POW 2 3 = 8
// out: PRED 3 = 2
// out: SUB 5 2 = 3
// out: FACT 3 = 6
// out: AND TRUE FALSE = FALSE
// out: OR FALSE TRUE = TRUE
// out: NOT (ISZERO 0) = FALSE
// out: S K K a = a
// out: (λx y.x y) y = λy′.y y′
// out: (λx.x x) (λx.x x) has no normal form within 10000 steps
