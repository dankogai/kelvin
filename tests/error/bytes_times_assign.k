// a Bytes has += alone (#766): any other operator of it was C's error
let main():int32 {
    var b:Bytes = Bytes()
    b += 1
    b *= 2
    return 0
}
// error: a Bytes has no '*='
