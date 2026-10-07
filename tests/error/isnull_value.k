// .isNull is for pointers and functions, which may be nullptr (#50)
let main():i32 {
    let k = 3
    println(k.isNull)
    return 0
}
// error: '.isNull' is a property of pointers and functions, and this is i64
