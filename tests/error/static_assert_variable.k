// a static_assert is judged as C compiles (#394): a variable, a let too, is
// no constant there
let main():i32 {
    let n = 8
    static_assert(n == 8)
    return 0
}
// error: a static_assert is judged as C compiles, before the program runs, and 'n' is a variable, which C does not count as a constant
