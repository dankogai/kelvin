// IO takes a path and a mode (#82)
let main():i32 {
    var f = IO("x")
    return 0
}
// error: IO takes a path and a mode, as in IO("log.txt", "w"): text, a String or a Bytes
