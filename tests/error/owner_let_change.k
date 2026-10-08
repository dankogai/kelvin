// a let owner cannot change (#54, O2)
let main():i32 {
    let a = Bytes("x")
    a.append("y")
    return 0
}
// error: 'a' is a let and cannot change; declare it with var
