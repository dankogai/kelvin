// text from a property lives until the enclosing block ends (#21):
// also in a brace-less for body and among a method call's arguments
i32.pass(p: u8^): u8^ { return p; }
i32.same(): i32 { return self; }

main(): i32
{
    a: i32 = 1;
    b: u64 = 255;
    c: u64 = 4096;
    v: u8^ := a.pass(b.dec);
    w: u8^ := a.pass(c.hex);
    t: u8^;
    for (k: i32 = 0; k < 1; k += 1)
        t := b.hex;
    u: u8^;
    for (i: i32 = 0; i < 3; i += 1)
        u := i.bin;
    println(v, " ", w, " ", t, " ", u);

    // nesting: each level is a temporary, not a copy of the one inside
    x: i32 = 42;
    println(x.hex[2].hex[2].hex[2].hex, " ", a.same().pass(c.oct));
    return 0;
}
// out: 255 0x1000 0xff +0b10
// out: 0x33 0o10000
