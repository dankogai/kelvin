// error: '.next' is a property of pointers to data, and (i64):i64 is a function
main():i32 {
    var f:(i64):i64;
    f := f.next;
    return 0;
}
