// Linked lists: structs named without `struct`, references (^ and :=),
// malloc and free from C, var methods that change the list they are
// called on (#318), and let methods that read it with for n in head, all
// in one extend list { } block.
#import <stdlib.h> as C

struct node {
    value: i64
    next:  node^       // a field, read as n^.next (n.next would be n + 1)
}

struct list {
    head:   node^
    length: i64
}

extend list {
    // add a value at the front: a var method, whose self is the caller's
    var push(value:i64) {
        let n := malloc(sizeof(node)) as node^
        if n == nowhere {
            exit(1)
        }
        n^.value = value
        n^.next := .head
        .head := n
        .length += 1
    }

    // remove the front value; the list must not be empty
    var pop():i64 {
        let first:node^ := .head
        let value:i64 = first^.value
        .head := first^.next
        .length -= 1
        free(first)
        return value
    }

    // reverse the list in place by turning each link around
    var reverse() {
        var done:node^     // a reference starts as nowhere
        var rest:node^ := .head
        while rest != nowhere {
            let next:node^ := rest^.next
            rest^.next := done
            done := rest
            rest := next
        }
        .head := done
    }

    // free every node
    var clear() {
        while .head != nowhere {
            .pop()
        }
    }

    // for n in head walks the nodes along next, up to nowhere
    let sum():i64 {
        var total = 0
        for n in .head {                                  // .head is self.head
            total += n^.value
        }
        return total
    }

    let contains(value:i64):bool {
        for n in .head {
            if n^.value == value {
                return true
            }
        }
        return false
    }

    // print the values as [1 -> 4 -> 9]
    let show() {
        print("[")
        for n in .head {
            print(n^.value)
            if n^.next != nowhere {
                print(" -> ")
            }
        }
        println("] (", .length, " values)")
    }
}

let main():i32 {
    var squares:list = {nowhere, 0}
    for i in 1...5 {
        squares.push(i * i)
    }
    squares.show()
    squares.reverse()
    squares.show()
    println("sum ", squares.sum(), ", has 16: ", squares.contains(16), ", has 15: ", squares.contains(15))
    println("popped ", squares.pop())
    squares.show()
    squares.clear()
    squares.show()
    return 0
}
// out: [25 -> 16 -> 9 -> 4 -> 1] (5 values)
// out: [1 -> 4 -> 9 -> 16 -> 25] (5 values)
// out: sum 55, has 16: true, has 15: false
// out: popped 1
// out: [4 -> 9 -> 16 -> 25] (4 values)
// out: [] (0 values)
