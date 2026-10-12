// OS.chmod takes the mode as an integer (#95)
let main():i32 {
    OS.chmod("x", "600")
    return 0
}
// error: argument 2 of OS.chmod is an integer, and this is not one
