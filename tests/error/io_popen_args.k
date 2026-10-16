// IO.popen takes a command and a mode (#87)
#import <IO>
let main():int32 {
    var p = IO.popen("ls")
    return 0
}
// error: IO.popen takes a command and a mode, as in IO.popen("ls -l", "r")
