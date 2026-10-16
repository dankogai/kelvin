// error: '.next' is a property of pointers: for an array, write '&a[1]'
let main():int32 {
    var a:[int32](3);
    var p:int32^ := a.next;
    return 0;
}
