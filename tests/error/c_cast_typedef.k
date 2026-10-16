// error: C casts are not Kelvin: write 'v as T', or 'T(v)' for a built-in type
let f(x:i32, n:u64) {
    var y:uint64 = (size_t)n;
}
