// error: 'i' counts the range and cannot change; copy it under another name, as in 'var k: i64 = i;'
main(): i32
{
    for i in 0..<3 {
        i = 5;
    }
    return 0;
}
