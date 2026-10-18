// '+' of a String (#183) joins text: a number is shown with a template or
// String(n), not added
let main():int32 {
    var s = $"n = "
    var t = s + 42
    return 0
}
// error: '+' of a String joins text: a String, a cstr or a uchr, and this is a number; show a number with a template, $`${n}`, or String(n)
