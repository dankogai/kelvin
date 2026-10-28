// String(x) of a String an expression gives is one already (#412)
let name():String { return $"kelvin" }
let main():int32 {
    let s = String(name())
    println(s)
    return 0
}
// error: String(x) of a String is one already: leave out String(...)
