// an array is never null (#50)
let main():int32 {
    let a:[int32](2) = [1, 2]
    println(a.isNull)
    return 0
}
// error: '.isNull' of an array: an array is never null; '&a[0]' is a pointer
