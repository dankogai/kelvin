// a function whose one expression gives an owner returns it (#81), as a
// written anonymous function, a trailing one, and a named one; an owner
// dropped elsewhere is still freed at once, or refused for a struct
let positive(n:i64):Result<i64, String> {
    if n == 0 { return err($"zero") }
    return n
}
let label(n:i64):String { $`#${n}` }
let main():i32 {
    let f := { (n:i64):Result<i64, String> in positive(n) }
    let g := { (n:i64):String in $`#${n}` }
    var r = f(0)
    var s = g(1)
    var t = label(2)
    println(r.cstr, " ", s, " ", t)
    $"dropped"                              // a String, freed at once
    return 0
}
// out: err(zero) #1 #2
// c: kv_string_discard(KV_STRING_OF("dropped"));
