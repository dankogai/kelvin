// rename changes the IO's path, so it needs the var that owns it (#101)
let main():i32 {
    let f = IO("x", "r")
    f.rename("y")
    return 0
}
// error: 'f' is a let and cannot change; declare it with var
