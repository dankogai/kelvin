// error: '.hex' text lives in a buffer of this function, which is gone once it returns
main():i32 {
    let skip:(u8):cstr := { $0.hex + 1 };
    return 0;
}
