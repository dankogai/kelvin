// Linked lists: structs and references (^ and :=), malloc and free from C,
// functions that change a list through a pointer, and methods that read it.
#import <stdlib.h> as C

struct node {
    value: i64;
    next: struct node^;     // a field, read as n^.next (n.next would be n + 1)
};

struct list {
    head: struct node^;
    length: i64;
};

// add a value at the front
push(l: struct list^, value: i64)
{
    let n := malloc(sizeof(struct node)) as struct node^;
    if n == nullptr {
        exit(1);
    }
    n^.value = value;
    n^.next := l^.head;
    l^.head := n;
    l^.length += 1;
}

// remove the front value; the list must not be empty
pop(l: struct list^): i64
{
    let first: struct node^ := l^.head;
    let value: i64 = first^.value;
    l^.head := first^.next;
    l^.length -= 1;
    free(first);
    return value;
}

// reverse the list in place by turning each link around
reverse(l: struct list^)
{
    var done: struct node^;             // a reference starts as nullptr
    var rest: struct node^ := l^.head;
    while rest != nullptr {
        let next: struct node^ := rest^.next;
        rest^.next := done;
        done := rest;
        rest := next;
    }
    l^.head := done;
}

// free every node
clear(l: struct list^)
{
    while l^.head != nullptr {
        pop(l);
    }
}

list.sum(): i64
{
    var total = 0;
    for (var n: struct node^ := self.head; n != nullptr; n := n^.next) {
        total += n^.value;
    }
    return total;
}

list.contains(value: i64): bool
{
    var n: struct node^ := self.head;
    while n != nullptr {
        if n^.value == value {
            return true;
        }
        n := n^.next;
    }
    return false;
}

// print the values as [1 -> 4 -> 9]
list.show()
{
    print("[");
    var n: struct node^ := self.head;
    while n != nullptr {
        print(n^.value);
        if n^.next != nullptr {
            print(" -> ");
        }
        n := n^.next;
    }
    println("] (", self.length, " values)");
}

main(): i32
{
    var squares: struct list = {nullptr, 0};
    for i in 1...5 {
        push(&squares, i * i);
    }
    squares.show();
    reverse(&squares);
    squares.show();
    println("sum ", squares.sum(), ", has 16: ", squares.contains(16), ", has 15: ", squares.contains(15));
    println("popped ", pop(&squares));
    squares.show();
    clear(&squares);
    squares.show();
    return 0;
}
// out: [25 -> 16 -> 9 -> 4 -> 1] (5 values)
// out: [1 -> 4 -> 9 -> 16 -> 25] (5 values)
// out: sum 55, has 16: true, has 15: false
// out: popped 1
// out: [4 -> 9 -> 16 -> 25] (4 values)
// out: [] (0 values)
