// SYS comes with OS (#145)
let main():int32 {
    println(SYS.argv.count)
    return 0
}
// error: SYS comes with OS, a module: write '#import <OS>' at the top of the file
