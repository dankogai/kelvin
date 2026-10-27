// a static_assert's message is a string literal (#394)
static_assert(1 == 1, 42)
let main():i32 { return 0 }
// error: a static_assert's message is a string literal: static_assert(cond, "message")
