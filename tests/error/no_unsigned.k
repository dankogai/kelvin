// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type; 'unsigned' is not a Kelvin type, use u8, u16, u32, u64 or u128
f()
{
    var n: u32 = (unsigned)1;
}
