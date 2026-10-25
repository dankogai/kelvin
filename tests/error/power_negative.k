// an integer to a negative power is no integer (#380)
let main():int32 {
    println(2 ** -1)
    return 0
}
// error: '**' of integers takes an exponent of 0 or more, and this is -1: a power of an integer less than 0 is no integer, but a floating-point one's is, as in '2.0 ** -1'
