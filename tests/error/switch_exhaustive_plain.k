// a switch on a Kelvin enum lists every enumerator, or has a default (#63)
enum color { red, green, blue }
let main():i32 {
    var c:color = red
    switch c {
    case red, green:
        println(0)
    }
    return 0
}
// error: switch on color is not exhaustive: blue is missing; write every enumerator, or add 'default:'
