// a Kelvin source is valid UTF-8 (#295): the byte 0xFF in the string
// below is none, an error where it stands, where it compiled before
let main():int32 {
    println("ÿ")
    return 0
}
// error: a Kelvin source is valid UTF-8, and byte 0xFF here is not (#295)
