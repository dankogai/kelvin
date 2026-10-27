// GNU C's __volatile__ is volatile (#399)
let main():i32 {
    var __volatile__ x:i32 = 1
    return 0
}
// error: '__volatile__' is a C compiler keyword; use volatile
