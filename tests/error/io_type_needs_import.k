// the type IO too is the module's (#144)
let show(f:IO^):() { f^.println("x") }
let main():int32 { return 0 }
// error: IO is a module: write '#import <IO>' at the top of the file
