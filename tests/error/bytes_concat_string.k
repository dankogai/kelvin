// '+' joins two Bytes or two Strings (#188): a String and a Bytes are told
// apart, as their bytes are text in one and anything in the other
let main():int32 {
    var b = Bytes("a")
    var s = $"b"
    var c = b + s
    return 0
}
// error: '+' joins two Bytes or two Strings: a String's bytes are 's.bytes^', and a Bytes of text is 'Bytes(&s)'
