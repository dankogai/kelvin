// an overloaded name where a function type is written is the overload of
// that type, and with none of it an error (#41, #223); kc says it as
// kelvinc does (#537)
let over(n:i64):i64 { n + 1 }
let over(x:f64):f64 { x + 0.5 }
let main():int32 {
    let h:(u8):u8 := over
    return 0
}
// error: no function 'over' is (u8):u8: C's function of the name is not taken where a Kelvin function has it (#223); declare C's beside it, as in 'let over(x:f64):f64'
