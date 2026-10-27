// a static_assert that does not hold stops the build (#394): C judges it,
// at the Kelvin line, with its message
static_assert(sizeof(i64) == 4, "i64 is four bytes")
let main():i32 { return 0 }
// error: static assertion failed
