// references (#19): `:=` assigns pointers, `=` assigns values
#import <stdlib.h> as C

struct node { value: i32; next: struct node^; };

sum(list: struct node^): i64
{
    total = 0;
    for (n: struct node^ := list; n != nullptr; n := n^.next)   // := also works inside expressions
        total += n^.value;
    return total;
}

main(): i32
{
    buffer := malloc(8 * 1024):i64^;        // declares buffer: i64^
    buffer[0] = 42;                         // a value, through the reference
    buffer^ = buffer^ + 1;
    println(buffer[0]);
    free(buffer);

    c: struct node = {3, 0 as struct node^};
    b: struct node = {2, &c};
    a: struct node = {1, &b};
    println(sum(&a));

    p: i32^ := &a.value;                    // typed declarations use := too
    q: i32^ := p;
    q := &b.value;                          // reassigning a reference
    q^ = 20;                                // assigning the value it refers to
    println(b.value, " ", p^);

    a.next := &c;                           // a field that is a reference
    a.next^.value = 30;
    println(sum(&a));

    refs: i32^[2] = {p, q};                 // an array of references is a value
    refs[1] := &c.value;
    println(refs[1]^);

    pp: i32^^ := &p;
    pp^ := q;                               // pp^ is a reference
    println(p^);

    q += 0;                                 // pointer arithmetic stays as in C
    q := q.next;                            // C: q++ (#26)
    q := q.prev;
    return 0;
}
// out: 43
// out: 6
// out: 20 1
// out: 31
// out: 30
// out: 20
