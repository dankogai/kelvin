// static_assert is a reserved word (#394)
let main():i32 {
    var static_assert = 1
    return 0
}
// error: expected a name, found 'static_assert'
