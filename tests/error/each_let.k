// error: 'c' is each element in turn and cannot change
main():i32 {
    let s:cstr := "ab";
    for c in s {
        c = 1;
    }
    return 0;
}
