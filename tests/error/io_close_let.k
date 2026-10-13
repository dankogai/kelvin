// close changes the IO itself, so it needs the var that owns it: a let
// cannot change (#82)
let main():i32 {
    let f = IO("x", "r")
    f.close()
    return 0
}
// error: 'f' is a let and cannot change; declare it with var
