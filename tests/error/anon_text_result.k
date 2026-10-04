// error: which is gone once it returns: the caller takes the text itself, as in '{ println($0.hex) }'
show(x:i64, f:(i64):cstr) { println(f(x)); }
main():i32 {
    show(255) { $0.hex }
    return 0;
}
