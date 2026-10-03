// error: expected '{': the body of 'for' is a block, as in 'for i in a..<b { ... }'
main():i32 {
    for i in 0..<3 println(i);
    return 0;
}
