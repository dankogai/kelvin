// Linked lists: structs named without `struct`, references (^ and :=),
// malloc and free from C, functions that change a list through a pointer,
// and methods that read it with for n in head.
#import <stdlib.h> as C

struct node {
    value:i64
    next:node^         // a field, read as n^.next (n.next would be n + 1)
}

struct list {
    head:node^
    length:i64
}

// add a value at the front
push(l:list^, value:i64) {
    let n := malloc(sizeof(node)) as node^
    if n == nullptr {
        exit(1)
    }
    n^.value = value
    n^.next := l^.head
    l^.head := n
    l^.length += 1
}

// remove the front value; the list must not be empty
pop(l:list^):i64 {
    let first:node^ := l^.head
    let value:i64 = first^.value
    l^.head := first^.next
    l^.length -= 1
    free(first)
    return value
}

// reverse the list in place by turning each link around
reverse(l:list^) {
    var done:node^     // a reference starts as nullptr
    var rest:node^ := l^.head
    while rest != nullptr {
        let next:node^ := rest^.next
        rest^.next := done
        done := rest
        rest := next
    }
    l^.head := done
}

// free every node
clear(l:list^) {
    while l^.head != nullptr {
        pop(l)
    }
}

// for n in head walks the nodes along next, up to nullptr
list.sum():i64 {
    var total = 0
    for n in self.head {
        total += n^.value
    }
    return total
}

list.contains(value:i64):bool {
    for n in self.head {
        if n^.value == value {
            return true
        }
    }
    return false
}

// print the values as [1 -> 4 -> 9]
list.show() {
    print("[")
    for n in self.head {
        print(n^.value)
        if n^.next != nullptr {
            print(" -> ")
        }
    }
    println("] (", self.length, " values)")
}

main():i32 {
    var squares:list = {nullptr, 0}
    for i in 1...5 {
        push(&squares, i * i)
    }
    squares.show()
    reverse(&squares)
    squares.show()
    println("sum ", squares.sum(), ", has 16: ", squares.contains(16), ", has 15: ", squares.contains(15))
    println("popped ", pop(&squares))
    squares.show()
    clear(&squares)
    squares.show()
    return 0
}
// out: [25 -> 16 -> 9 -> 4 -> 1] (5 values)
// out: [1 -> 4 -> 9 -> 16 -> 25] (5 values)
// out: sum 55, has 16: true, has 15: false
// out: popped 1
// out: [4 -> 9 -> 16 -> 25] (4 values)
// out: [] (0 values)
