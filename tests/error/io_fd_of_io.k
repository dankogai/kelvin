// IO(fd, mode) takes the descriptor number, not an IO (#86)
let main():i32 {
    var f = IO.stdin
    var g = IO(f, "r")
    return 0
}
// error: IO takes a descriptor number here: an IO's is 'f.fd'
