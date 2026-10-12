// IO's streams are stdin, stdout and stderr (#82)
let main():i32 {
    var f = IO.stdlog
    return 0
}
// error: IO has stdin, stdout and stderr, not 'stdlog'; a file is IO(path, mode)
