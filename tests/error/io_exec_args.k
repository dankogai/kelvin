// IO.exec takes a list of arguments, or an Array of them (#90)
#import <IO>
let main():int32 {
    var p = IO.exec("ls -l", "r")
    return 0
}
// error: IO.exec takes a list of arguments, ["ls", "-l"], or an Array of cstr or of String in a variable, and this is one text: write the program and each argument apart, with no shell to split them
