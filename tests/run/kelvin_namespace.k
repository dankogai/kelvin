// Kelvin.name (#600) is the prelude's name, whatever the program calls
// its own: Kelvin.log is the prelude's log beside a log of the program's.
// It chooses among the prelude's overloads alone. A function of the
// program's with the name and the types of one of the prelude's is
// another function, called by the bare name, where it took the prelude's
// place, log(x:f64), or did not link, abs(n:i64), which libkelvin
// defines. A variable or a parameter of the name hides the bare name and
// not Kelvin's, in C too. print, println and the types that are words
// are the same with Kelvin. and without
let log(s:cstr) { println("log: ", s) }
let log(x:f64):f64 { x + 1.0 }
let abs(n:i64):i64 { 42 }
let sqrt(x:i64):i64 { 7 }
let twice(exp:f64, abs:i64):f64 { Kelvin.exp(exp) * 2.0 + Kelvin.abs(abs) as f64 }
let main():int32 {
    log("mine")
    println(log(1.0), " ", Kelvin.log(1.0), " ", abs(-3), " ", Kelvin.abs(-3), " ", abs(-2.5), " ", Kelvin.abs(-2.5))
    println(sqrt(16), " ", Kelvin.sqrt(16.0), " ", sqrt(16.0))
    let sqrt = 9.0
    let f:(f64):f64 := Kelvin.sqrt
    println(Kelvin.sqrt(sqrt), " ", f(sqrt), " ", twice(0.0, -5))
    Kelvin.println(Kelvin.c64(3.0, 4.0), " ", Kelvin.abs(Kelvin.c64(3.0, 4.0)), " ", Kelvin.BigInt("12") + 1n)
    let s:Kelvin.String = $"é"
    let nfd = 0
    println(s.normalize(Kelvin.nfd).codepoints.count, " ", nfd, " ", Kelvin.f64.pi > 3.0, " ", Kelvin.grapheme(0x41))
    return 0
}
// out: log: mine
// out: 2.0 0.0 42 3 2.5 2.5
// out: 7 4.0 4.0
// out: 3.0 3.0 7.0
// out: (3.0+4.0.i) 5.0 13n
// out: 2 0 true ok("A")
