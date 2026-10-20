// Kelvin has no trigraphs (#220): C11 reads two '?' and one of = ( / ) '
// < ! > - as another character, before anything else, but kelvinc writes
// a '?' after a '?' as \?, so a string is what it says. In #inline C the
// same holds of its strings, characters and comments, and a T?? names
// its type as it is
// out: what??! a??(b??) ??= ??' ??< ??> ??- ???
// out: really??! 9
// out: tpl??! 1 ??/
// out: C??! 63
// out: i64??
#inline C {
    // a comment that ends as a trigraph would join the next line to it??/
    static const char *shout(void) { return "C??!"; }   /* or??/ */
    static char quest(void) { return '?'; }
}

let main(argc:int32, argv:[cstr]):int32 {
    println("what??! a??(b??) ??= ??' ??< ??> ??- ???")
    let s = $"really??!"
    println(s, " ", s.count)
    let t := `tpl??! ${argc} ??/`
    println(t)
    println(shout(), " ", quest() as uint8)
    let m:int64?? = none
    println(m.typename)
    return 0
}
