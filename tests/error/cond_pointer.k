// error: a condition must be a bool, not u8^: compare it, as in 'p != nullptr'
main(): i32
{
    p: u8^ := "text";
    while p {
        p := nullptr;
    }
    return 0;
}
