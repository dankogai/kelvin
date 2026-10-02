// error: '.next' is a property of pointers: for an array, write '&a[1]'
main(): i32
{
    var a: i32[3];
    var p: i32^ := a.next;
    return 0;
}
