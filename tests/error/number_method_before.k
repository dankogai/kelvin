// a number's method written after its call is seen (#543), so a type
// that has none of the name is still told which type has it (#539)
let main():int32 {
    let n:u8 = 3
    println(n.later())
    return 0
}
let i64.later():i64 { self * 2 }
// error: u8 has no method 'later': it is a method of 'i64'
