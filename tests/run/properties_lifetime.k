// text from a property lives until the enclosing block ends (#21):
// also in a brace-less for body and among a method call's arguments
let int32.pass(p:uint8^):uint8^ { return p; }
let int32.same():Self { return self; }

let main():int32 {
    var a:int32 = 1;
    var b:uint64 = 255;
    var c:uint64 = 4096;
    var v:uint8^ := a.pass(b.dec);
    var w:uint8^ := a.pass(c.hex);
    var t:uint8^;
    for (var k:int32 = 0; k < 1; k += 1)
        t := b.hex;
    var u:uint8^;
    for (var i:int32 = 0; i < 3; i += 1)
        u := i.bin;
    println(v, " ", w, " ", t, " ", u);

    // nesting: each level is a temporary, not a copy of the one inside
    var x:int32 = 42;
    println(x.hex[2].hex[2].hex[2].hex, " ", a.same().pass(c.oct));
    return 0;
}
// out: 255 0x1000 0xff +0b10
// out: 0x33 0o10000
