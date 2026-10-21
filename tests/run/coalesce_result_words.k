// r ?? ok(v) and r ?? err(e) (#254): the words make a Result of r's
// type, so the result is that Result, r where it is ok, else the one
// the word makes, as r ?? r2 (#253); err($"...") moves its value in,
// and a copy is written .copy()
// out: ok(0) ok(7) err("other") ok(7)
// out: ok(9) err("e")
// out: ok("ok") err("fb") fb
let parse(s:cstr):Result<int64, String> {
    if s[0] >= '0' && s[0] <= '9' { return s[0] as int64 - 48 }
    return err($"not a digit")
}

let main():int32 {
    var a = parse("x")
    var b = parse("7")
    println(a ?? ok(0), " ", b ?? ok(0), " ", a ?? err($"other"), " ", b ?? err($"other"))
    println(parse("q") ?? ok(9), " ", parse("q") ?? err($"e"))
    var s:Result<String, String> = err($"e1")
    let fb = $"fb"
    println(s ?? ok($"ok"), " ", s ?? err(fb.copy()), " ", fb)
    return 0
}
