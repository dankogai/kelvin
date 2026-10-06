// text from a property lives until the enclosing block ends (#21):
// also in a brace-less for body and among a method call's arguments
let i32.pass(p:u8^):u8^ { return p; }
let i32.same():i32 { return self; }

let main():i32 {
    var a:i32 = 1;
    var b:u64 = 255;
    var c:u64 = 4096;
    var v:u8^ := a.pass(b.dec);
    var w:u8^ := a.pass(c.hex);
    var t:u8^;
    for (var k:i32 = 0; k < 1; k += 1)
        t := b.hex;
    var u:u8^;
    for (var i:i32 = 0; i < 3; i += 1)
        u := i.bin;
    println(v, " ", w, " ", t, " ", u);

    // nesting: each level is a temporary, not a copy of the one inside
    var x:i32 = 42;
    println(x.hex[2].hex[2].hex[2].hex, " ", a.same().pass(c.oct));
    return 0;
}
// out: 255 0x1000 0xff +0b10
// out: 0x33 0o10000
