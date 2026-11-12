// a rational is of signed integers alone (#539): n.over(d) is a method of
// i8, i16, i32 and i64, and of a BigInt (#540), and an unsigned integer
// has none
#import <Rational>
let main():int32 {
    let n:u8 = 1
    println(n.over(3))
    return 0
}
// error: u8 has no method 'over': it is a method of 'i64', 'i32', 'i16', 'i8', 'BigInt'
