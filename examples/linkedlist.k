// Linked lists: structs named without `struct`, references (^ and :=),
// malloc and free from C, functions of the type that change a list through
// a pointer, list.push(&l, v), and methods that read it with for n in head,
// all in one extend list { } block with Self for list.
#import <stdlib.h> as C

struct node {
    value: int64
    next:  node^       // a field, read as n^.next (n.next would be n + 1)
}

struct list {
    head:   node^
    length: int64
}

extend list {
    // add a value at the front: a function of the type (#111), since it changes
    // the list through a pointer, while a method's self is a let (#138)
    static let push(l:Self^, value:int64):() {
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
    static let pop(l:Self^):int64 {
        let first:node^ := l^.head
        let value:int64 = first^.value
        l^.head := first^.next
        l^.length -= 1
        free(first)
        return value
    }

    // reverse the list in place by turning each link around
    static let reverse(l:Self^):() {
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
    static let clear(l:Self^):() {
        while l^.head != nullptr {
            Self.pop(l)
        }
    }

    // for n in head walks the nodes along next, up to nullptr
    let sum():int64 {
        var total = 0
        for n in .head {                                  // .head is self.head
            total += n^.value
        }
        return total
    }

    let contains(value:int64):bool {
        for n in .head {
            if n^.value == value {
                return true
            }
        }
        return false
    }

    // print the values as [1 -> 4 -> 9]
    let show():() {
        print("[")
        for n in .head {
            print(n^.value)
            if n^.next != nullptr {
                print(" -> ")
            }
        }
        println("] (", .length, " values)")
    }
}

let main():int32 {
    var squares:list = {nullptr, 0}
    for i in 1...5 {
        list.push(&squares, i * i)
    }
    squares.show()
    list.reverse(&squares)
    squares.show()
    println("sum ", squares.sum(), ", has 16: ", squares.contains(16), ", has 15: ", squares.contains(15))
    println("popped ", list.pop(&squares))
    squares.show()
    list.clear(&squares)
    squares.show()
    return 0
}
// out: [25 -> 16 -> 9 -> 4 -> 1] (5 values)
// out: [1 -> 4 -> 9 -> 16 -> 25] (5 values)
// out: sum 55, has 16: true, has 15: false
// out: popped 1
// out: [4 -> 9 -> 16 -> 25] (4 values)
// out: [] (0 values)
