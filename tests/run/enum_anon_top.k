// an enum with values and no tag at the top level (#120): its type is the
// one of its spelling, as where a type goes, and its cases are words of
// the program, as C's anonymous enum declares its enumerators: red is a
// value, rgb({1, 2, 3}) and named($"teal") make one, and a declaration
// infers the type from them
enum { red; rgb: {r: uint8, g: uint8, b: uint8}; named: String }
let show(c:const enum{red, rgb: {r: uint8, g: uint8, b: uint8}, named: String}^) {
    switch c^ {
    case red: println("red")
    case rgb(p): println("rgb ", p.r, " ", p.g, " ", p.b)
    case named(s): println("named ", s)
    }
}
enum { crimson, blue }               // C's anonymous enum, as before: constants
let main():int32 {
    var a = red
    var b = rgb({1, 2, 3})
    var c = named($"teal")
    println(a.cstr, " ", b.rgb.g, " ", c.named, " ", b.typename)
    show(&a)
    show(&b)
    show(&c)
    var xs = $[rgb({4, 5, 6}), red]
    println(xs.count, " ", xs[0].rgb.b, " ", xs[1].is(red))
    var d:enum{red, rgb: {r: uint8, g: uint8, b: uint8}, named: String} = {.named = $"by initializer"}
    println(d.named, " ", d.is(named), " ", blue)
    d = red
    println(d.cstr)
    return 0
}
// out: red 2 teal enum{red, rgb: {r: u8, g: u8, b: u8}, named: String}
// out: red
// out: rgb 1 2 3
// out: named teal
// out: 2 6 true
// out: by initializer true 1
// out: red
