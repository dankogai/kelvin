// the separator of xs.join(sep) is text (#461): a cstr, a String or a
// uchr, not a number to show
let main():int32 {
    let xs = $[1, 2]
    println(xs.join(0))
    return 0
}
// error: '.join' puts text between the elements: a cstr, a String or a uchr, and this is a number
