// SYS is the prelude's (#302): the program's arguments, its platform and
// its exit with no import, where it came with OS, a module (#145), and
// "SYS comes with OS" was an error; main gives it its arguments
let shown():int64 { SYS.argv.count as int64 }
let main():int32 {
    let p := SYS.platform
    println(shown(), " ", SYS.argv[0].count > 0, " ", p.count > 0)
    SYS.exit(0)
    return 1
}
// out: 1 true true
