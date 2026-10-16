// references (#19): `:=` assigns pointers, `=` assigns values
#import <stdlib.h> as C

struct node { value:int32; next:struct node^; };

let sum(list:struct node^):int64 {
    var total = 0;
    for (var n:struct node^ := list; n != nullptr; n := n^.next)   // := also works inside expressions
        total += n^.value;
    return total;
}

let main():int32 {
    var buffer := malloc(8 * 1024):int64^;        // declares buffer: i64^
    buffer[0] = 42;                         // a value, through the reference
    buffer^ = buffer^ + 1;
    println(buffer[0]);
    free(buffer);

    var c:struct node = {3, 0 as struct node^};
    var b:struct node = {2, &c};
    var a:struct node = {1, &b};
    println(sum(&a));

    var p:int32^ := &a.value;                    // typed declarations use := too
    var q:int32^ := p;
    q := &b.value;                          // reassigning a reference
    q^ = 20;                                // assigning the value it refers to
    println(b.value, " ", p^);

    a.next := &c;                           // a field that is a reference
    a.next^.value = 30;
    println(sum(&a));

    var refs:[int32^](2) = [p, q];                 // an array of references is a value
    refs[1] := &c.value;
    println(refs[1]^);

    var pp:int32^^ := &p;
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
