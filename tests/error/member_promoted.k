// error: i32 has no member 'foo'
// a member of arithmetic whose type is C's is kelvinc's error, where it
// was C's (#669): n + 1 of a u8 is C's int, an i32, and u8's foo is not
// of it
extend u8 { let foo:bool { self > 2 } }
let main():int32 {
    let n:u8 = 3
    println((n + 1).foo)
    return 0
}
