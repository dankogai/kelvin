// b[i] is checked: out of range aborts (#54, O9), which the C compiler
// cannot see, so this test is of kelvinc only where it matters: a let
// element cannot be assigned
let main():i32 {
    let a = Bytes("xy")
    a[0] = 1
    return 0
}
// error: 'a' is a let and cannot change; declare it with var
