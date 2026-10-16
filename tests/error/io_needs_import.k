// IO is a module (#144): a program imports it
let main():int32 {
    var f = IO("/dev/null", "r")
    return 0
}
// error: IO is a module: write '#import <IO>' at the top of the file
