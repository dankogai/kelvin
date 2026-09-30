printf(fmt: const u8^, ...): i32;

struct node {
    value: i32;
    next: struct node^;
};

sum(n: struct node^): i32
{
    var total: i32 = 0;
    while (n) {
        total += n^.value;      // C: n->value
        n = n^.next;
    }
    return total;
}

swap(a: i32^, b: i32^)
{
    var t: i32 = a^;            // C: *a
    a^ = b^;
    b^ = t;
}

main(argc: i32, argv: u8^^): i32
{
    var c: struct node = {3, 0};
    var b: struct node = {2, &c};
    var a: struct node = {1, &b};
    printf("%d\n", sum(&a));

    var x: i32 = 1, y: i32 = 2;
    swap(&x, &y);
    printf("%d %d\n", x, y);

    var p: i32^ = &x;
    var pp: i32^^ = &p;
    pp^^ = 42;                  // C: **pp
    printf("%d\n", x);

    var arr: i32[3] = {10, 20, 30};
    var q: i32^ = arr;
    printf("%d %d\n", q[1], (q + 2)^);
    printf("%d\n", q++^);       // C: *q++
    printf("%d\n", q^);

    var rows: i32[2][3] = {{1, 2, 3}, {4, 5, 6}};
    var row: i32[3]^ = &rows[1];     // pointer to array of 3 i32
    printf("%d %d\n", row^[2], (i32)(sizeof rows / sizeof rows[0]));

    var names: const u8^[2] = {"alpha", "beta"};   // array of 2 pointers
    printf("%s %s\n", names[0], argv[0] ? "argv ok" : "no argv");
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
