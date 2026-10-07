// an array is never null (#50)
let main():i32 {
    let a:[i32](2) = [1, 2]
    println(a.isNull)
    return 0
}
// error: '.isNull' of an array: an array is never null; '&a[0]' is a pointer
