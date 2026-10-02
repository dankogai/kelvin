// error: '.next' is a property of pointers: for an array, write '&a[1]'
main(): i32
{
    a: i32[3];
    p: i32^ := a.next;
    return 0;
}
