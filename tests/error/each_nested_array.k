// error: for over an array of arrays: index it
main():i32 {
    let m:i32[2][2] = {{1, 2}, {3, 4}};
    for r in m {
    }
    return 0;
}
