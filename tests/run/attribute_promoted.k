// an attribute of arithmetic is of C's type of it (#669): n + 1 of a u8 is
// an i32, whose attribute it reads, and (n + 1) as u8 a u8
extend u8 { let small:bool { self < 10 } }
extend i32 { let small:bool { self < 100 } }
let main():int32 {
    let n:u8 = 50
    println((n + 1).small, " ", ((n + 1) as u8).small, " ", (n * 2).typename)
    return 0
}
// out: true false i32
