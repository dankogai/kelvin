// print and println take up to 16 values (P22); kelvinc says so, where C
// would report a pasted token
let main():i32 {
    println(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17)
    return 0
}
// error: println takes up to 16 values, and this has 17: write two calls
