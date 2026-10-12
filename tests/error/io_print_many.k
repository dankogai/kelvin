// f.print takes up to 16 values (#83)
let main():i32 {
    IO.stdout.print(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17)
    return 0
}
// error: '.print' takes up to 16 values, and this has 17: write two calls
