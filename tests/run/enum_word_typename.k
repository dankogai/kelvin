// an enum's word is of its enum to .typename, as a variable of it is
// (#622): a program's own and the prelude's; .size and an integer's
// methods are C's int still (#469), and 42 is C's int
enum color { red, green }
let main():int32 {
    let c = green
    println(red.typename, " ", c.typename, " ", nfc.typename, " ", Kelvin.nfd.typename)
    println(red.size, " ", green.abs, " ", 42.typename)
    return 0
}
// out: color color NormalForm NormalForm
// out: 4 1 i32
