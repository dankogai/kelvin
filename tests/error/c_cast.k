// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type
f(x: i32, n: u64)
{
    var y: i64 = (i64)x;
}
