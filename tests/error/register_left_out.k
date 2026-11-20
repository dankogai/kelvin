// register is C's hint, which compilers decide for themselves, and
// Kelvin leaves it out on purpose (#640)
let main():int32 {
    register var n:i64 = 1
    println(n)
    return 0
}
// error: 'register' is C's hint to keep a variable in a register, which compilers decide for themselves: Kelvin leaves it out on purpose (#640); write 'var' alone
