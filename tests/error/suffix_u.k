// error: '0x1Fu': literals have no suffixes in Kelvin; put the type on the declaration, e.g. 'x: u64 = 0x1F'
f()
{
    var mask: u32 = 0x1Fu;
}
