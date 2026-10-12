// close changes the IO itself, so it needs the var that owns it: a let, as
// if let binds, holds a copy, and closing through it would close twice (#82)
let main():i32 {
    var r = IO("x", "r")
    if let ok(f) = r { f.close() }
    return 0
}
// error: 'f' is a let and cannot change; declare it with var
