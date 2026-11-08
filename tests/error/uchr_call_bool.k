// uchr(x) of a bool is a Kelvin error, where it was C's (#494)
let main():int32 {
    println(uchr(true))
    return 0
}
// error: uchr(x) takes an integer, a uchr or text, and this is a bool
