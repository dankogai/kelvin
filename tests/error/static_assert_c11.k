// C11's _Static_assert is spelled static_assert, C23's name (#394)
_Static_assert(1, "c11")
let main():i32 { return 0 }
// error: '_Static_assert' is C11's spelling: Kelvin writes static_assert(cond, "message"), its message optional
