let printf(fmt:const uint8^, ...):int32;

struct node {
    value:int32;
    next:struct node^;
};

let sum(var n:struct node^):int32 {
    var total:int32 = 0;
    while n != nullptr {
        total += n^.value;      // C: n->value
        n := n^.next;
    }
    return total;
}

let swap(a:int32^, b:int32^) {
    var t:int32 = a^;            // C: *a
    a^ = b^;
    b^ = t;
}

let main(argc:int32, argv:uint8^^):int32 {
    var c:struct node = {3, 0};
    var b:struct node = {2, &c};
    var a:struct node = {1, &b};
    printf("%d\n", sum(&a));

    var x:int32 = 1, y:int32 = 2;
    swap(&x, &y);
    printf("%d %d\n", x, y);

    var p:int32^ := &x;
    var pp:int32^^ := &p;
    pp^^ = 42;                  // C: **pp
    printf("%d\n", x);

    var arr:[int32](3) = [10, 20, 30];
    var q:int32^ := arr;
    printf("%d %d\n", q[1], (q + 2)^);
    printf("%d\n", q^);         // C: *q++ is two statements (#26)
    q := q.next;
    printf("%d\n", q^);

    var rows:[[int32](3)](2) = [[1, 2, 3], [4, 5, 6]];
    var row:[int32](3)^ := &rows[1];     // pointer to array of 3 i32
    printf("%d %d\n", row^[2], int32(sizeof rows / sizeof rows[0]));

    var names:[const uint8^](2) = ["alpha", "beta"];   // array of 2 pointers
    printf("%s %s\n", names[0], argv[0] != nullptr ? "argv ok" : "no argv");
    return 0;
}
// out: 6
// out: 2 1
// out: 42
// out: 20 30
// out: 10
// out: 20
// out: 6 2
// out: alpha argv ok
