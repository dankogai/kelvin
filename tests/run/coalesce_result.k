// r ?? r2 of two Results of a type (#253): a Result, r where it is ok,
// else r2, as a ?? b of two Optionals (#252); a r2 of the ok value's
// type still gives the value, so a chain ends with one: r ?? r2 ?? 0.
// Where the Result owns, as by its err, r and r2 are copied where they
// are places, else taken, and a taken r that is err is freed
// out: ok(7) ok(3) err("not a digit") ok(4) ok(1)
// out: err("not a digit") 7 -1
// out: ok("ok2") ok("ok2") err("e1")
// out: ok("ok2") err("e1")
let parse(s:cstr):Result<int64, String> {
    if s[0] >= '0' && s[0] <= '9' { return s[0] as int64 - 48 }
    return err($"not a digit")
}

let main():int32 {
    var a = parse("x")
    var b = parse("7")
    var c = parse("3")
    println(a ?? b, " ", c ?? b, " ", a ?? a, " ", parse("y") ?? parse("4"), " ", parse("1") ?? a)
    let d = a ?? parse("z")
    println(d, " ", a ?? b ?? 0, " ", parse("q") ?? parse("w") ?? -1)
    var s:Result<String, String> = err($"e1")
    var t:Result<String, String> = $"ok2"
    println(s ?? t, " ", t ?? s, " ", s ?? s)
    let u = s ?? t
    println(u, " ", s)
    return 0
}
