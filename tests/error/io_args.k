// IO takes a path, and a mode or none (#82, #101)
let main():i32 {
    var f = IO()
    return 0
}
// error: IO takes a path and a mode, as in IO("log.txt", "w"): text, a String or a Bytes; a path alone opens for reading (#101)
