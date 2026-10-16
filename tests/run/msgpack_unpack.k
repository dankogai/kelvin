// MsgPack.unpack (#153): every format, uint included, a float 32 as a
// double, timestamps as dates, other exts as exts holding their encoding,
// and errors for bytes that are not MessagePack
#import <MsgPack>
let show(b:cstr, n:i64):() {
    var bytes = Bytes(b, n)
    var v = MsgPack.unpack(&bytes)
    var t = SION.stringify(&v)
    println(t)
}
let main():int32 {
    show("\x05", 1)
    show("\xff", 1)
    show("\xcc\xff\xcd\x01\x00", 2)
    show("\xcd\x01\x00", 3)
    show("\xce\x00\x01\x00\x00", 5)
    show("\xcf\x00\x00\x00\x00\x00\x00\x00\x2a", 9)
    show("\xcf\xff\xff\xff\xff\xff\xff\xff\xff", 9)
    show("\xd0\xfe", 2)
    show("\xd1\xff\x00", 3)
    show("\xd2\x80\x00\x00\x00", 5)
    show("\xd3\xff\xff\xff\xff\xff\xff\xff\xfe", 9)
    show("\xca\x3f\xc0\x00\x00", 5)
    show("\xcb\x3f\xf8\x00\x00\x00\x00\x00\x00", 9)
    show("\xa2hi", 3)
    show("\xd9\x03" "abc", 5)
    show("\xc4\x02\x01\x02", 4)
    show("\xd6\xff\x00\x00\x00\x2a", 6)
    show("\xd7\xff\x00\x00\x00\x00\x00\x00\x00\x2a", 10)
    show("\xc7\x0c\xff\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff", 15)
    show("\xd4\xd4\xd4", 3)
    show("\xc7\x02\x05\x01\x02", 5)
    show("\x92\x01\xa1x", 4)
    show("\x81\xa1k\xc3", 4)
    show("\xdc\x00\x02\x01\x02", 5)
    show("\xde\x00\x01\x01\x02", 5)
    show("\xc1", 1)
    show("\x92\x01", 2)
    show("\x01\x02", 2)
    show("\xa3" "ab", 3)
    return 0
}
// out: 5
// out: -1
// out: 255
// out: 256
// out: 65536
// out: 42
// out: "an uint 64 past an i64 at 0"
// out: -2
// out: -256
// out: -2147483648
// out: -2
// out: 0x1.8p+0
// out: 0x1.8p+0
// out: "hi"
// out: "abc"
// out: .Data("AQI=")
// out: .Date(0x1.5p+5)
// out: .Date(0x1.5p+5)
// out: .Date(-0x1p+0)
// out: .Ext("1NTU")
// out: .Ext("xwIFAQI=")
// out: [1,"x"]
// out: ["k":true]
// out: [1,2]
// out: [1:2]
// out: "not a MessagePack format byte at 0"
// out: "a value ends past the bytes at 2"
// out: "bytes after the value at 1"
// out: "a string ends past the bytes at 1"
