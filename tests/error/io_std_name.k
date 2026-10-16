// IO's streams are stdin, stdout and stderr (#82)
#import <IO>
let main():int32 {
    var f = IO.stdlog
    return 0
}
// error: IO has stdin, stdout, stderr, popen(command, mode), exec(args, mode), pipe() and strerror(err), not 'stdlog'; a file is IO(path, mode)
