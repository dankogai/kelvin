// SKI combinator logic, and Iota and Jot, the two languages of one
// combinator that compile to it. A term is S, K, I, a variable a..z, or
// one term applied to another, written left to right: SKKa is ((SK)K)a.
// Terms are reduced leftmost-outermost, one step at a time, to a normal
// form, or until a limit of steps:
//   I x = x    K x y = x    S x y z = x z (y z)
// Iota writes ι for λx.xSK and * for an application, prefixed: *ii is
// ιι. Jot is a string of bits, read left to right from I:
//   [w0] = [w] S K    [w1] = S (K [w])
// The nodes live in one Array and refer to each other by index, so a
// step builds new nodes and shares the old ones, and nothing is freed
// until the program ends.
//   kelvinc --run examples/ski.k                    the examples below
//   kelvinc --run examples/ski.k -- 'S(K(SI))Kab'   a term of SKI
//   kelvinc --run examples/ski.k -- -iota '*i*i*ii' a term of Iota
//   kelvinc --run examples/ski.k -- -jot 11100      a term of Jot
#import <string.h> as C

struct node {
    kind: uint8         // 'S', 'K', 'I', a variable, or '@', an application
    fun: int64          // of an application: the function and its argument
    arg: int64
}

var pool:$[node]        // every node, by index; a global owner, filled by main

let make(kind:uint8, fun:int64, arg:int64):int64 {
    let n:node = {kind, fun, arg}
    pool += n
    return pool.count as int64 - 1
}
let atom(kind:uint8):int64 { make(kind, -1, -1) }
let ap(f:int64, x:int64):int64 { make('@', f, x) }

// ---------- SKI ----------

// a term of SKI from s, from at^ to its end or a ')' of an enclosing one;
// -1 where there is none
let sequence(s:cstr, at:int64^):int64 {
    var t:int64 = -1
    while s[at^] != 0 && s[at^] != ')' {
        let c = s[at^]
        at^ += 1
        var x:int64 = -1
        if c == '(' {
            x = sequence(s, at)
            if s[at^] == ')' { at^ += 1 }
        } else if c == 'S' || c == 'K' || c == 'I' || (c >= 'a' && c <= 'z') {
            x = atom(c)
        }
        if x >= 0 { t = t < 0 ? x : ap(t, x) }
    }
    return t
}

let ski(s:cstr):int64 {
    var at:int64 = 0
    return sequence(s, &at)
}

// the text of t: an application left to right, an argument that is one in
// parentheses
let show(t:int64):String {
    let n = pool[t]
    if n.kind != '@' { return $"" + n.kind.uchr }
    var s = show(n.fun)
    if pool[n.arg].kind == '@' {
        s += "("
        s += show(n.arg)
        s += ")"
    } else {
        s += show(n.arg)
    }
    return s
}

// one step of leftmost-outermost reduction of t, or -1 where t is normal
let step(t:int64):int64 {
    var args:$[int64] = $[]             // the arguments of the head, the last first
    var h = t
    while pool[h].kind == '@' {
        args += pool[h].arg
        h = pool[h].fun
    }
    let n = args.count as int64
    let k = pool[h].kind
    var r:int64 = -1
    var used:int64 = 0
    if k == 'I' && n >= 1 {
        r = args[n - 1]
        used = 1
    } else if k == 'K' && n >= 2 {
        r = args[n - 1]
        used = 2
    } else if k == 'S' && n >= 3 {
        let x = args[n - 1]
        let y = args[n - 2]
        let z = args[n - 3]
        r = ap(ap(x, z), ap(y, z))
        used = 3
    }
    if r >= 0 {                          // the rest of the arguments, in order
        var j:int64 = n - used - 1
        while j >= 0 {
            r = ap(r, args[j])
            j -= 1
        }
        return r
    }
    for i in 0..<n {                     // the head is stuck: the first argument that steps
        let next = step(args[n - 1 - i])
        if next >= 0 {
            var u = h
            for j in 0..<n { u = ap(u, j == i ? next : args[n - 1 - j]) }
            return u
        }
    }
    return -1
}

// t reduced to its normal form, as its text, or what is left after limit
// steps, marked with "..."
let normal(t:int64, limit:int64):String {
    var u = t
    for i in 0..<limit {
        let next = step(u)
        if next < 0 { return show(u) }
        u = next
    }
    return show(u) + " ..."
}

// ---------- Iota ----------

// ι, λx.xSK, as S(SI(KS))(KK)
let iota_combinator():int64 { ski("S(SI(KS))(KK)") }

// a term of Iota from s at at^: `*` and two terms, or `i`
let iota_term(s:cstr, at:int64^):int64 {
    let c = s[at^]
    if c == 0 { return -1 }
    at^ += 1
    if c == '*' {
        let f = iota_term(s, at)
        let x = iota_term(s, at)
        return f < 0 || x < 0 ? -1 : ap(f, x)
    }
    return c == 'i' ? iota_combinator() : iota_term(s, at)   // anything else is skipped
}

let iota(s:cstr):int64 {
    var at:int64 = 0
    return iota_term(s, &at)
}

// ---------- Jot ----------

let jot(s:cstr):int64 {
    var w = atom('I')
    for c in s {
        if c == '0' {
            w = ap(ap(w, atom('S')), atom('K'))
        } else if c == '1' {
            w = ap(atom('S'), ap(atom('K'), w))
        }
    }
    return w
}

// ---------- the examples ----------

let limit:int64 = 1000

// t applied to the variables of vars, reduced: what the combinator does
let apply(name:cstr, t:int64, vars:cstr):() {
    var u = t
    for v in vars { u = ap(u, atom(v)) }
    println(name, " ", vars, " = ", normal(u, limit))
}

let main(argc:int32, argv:[cstr]):int32 {
    if argc > 2 && strcmp(argv[1], "-iota") == 0 {
        println(normal(iota(argv[2]), limit))
        return 0
    }
    if argc > 2 && strcmp(argv[1], "-jot") == 0 {
        println(normal(jot(argv[2]), limit))
        return 0
    }
    if argc > 1 {
        let t = ski(argv[1])
        if t < 0 {
            println("no term in ", argv[1])
            return 1
        }
        println(normal(t, limit))
        return 0
    }
    // SKI
    let terms:[cstr](6) = ["SKKa", "S(K(SI))Kab", "S(KS)Kabc", "SIIa", "KIab", "SII(SII)"]
    for s in terms { println(s, " = ", normal(ski(s), 10)) }
    // Iota: *ii is I, *i*i*ii is K, *i*i*i*ii is S
    apply("*ii", iota("*ii"), "a")
    apply("*i*i*ii", iota("*i*i*ii"), "ab")
    apply("*i*i*i*ii", iota("*i*i*i*ii"), "abc")
    // Jot: the empty string is I, 11100 is K, 11111000 is S
    apply("[]", jot(""), "a")
    apply("11100", jot("11100"), "ab")
    apply("11111000", jot("11111000"), "abc")
    println(pool.count, " nodes")
    return 0
}
// out: SKKa = a
// out: S(K(SI))Kab = ba
// out: S(KS)Kabc = a(bc)
// out: SIIa = aa
// out: KIab = b
// out: SII(SII) = I(I(I(I(SII))))(I(I(I(I(SII))))) ...
// out: *ii a = a
// out: *i*i*ii ab = a
// out: *i*i*i*ii abc = ac(bc)
// out: [] a = a
// out: 11100 ab = a
// out: 11111000 abc = ac(bc)
// out: 922 nodes
