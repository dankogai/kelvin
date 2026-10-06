// for x in s (#30): each element of a sequence that ends at a terminator
#import <stdlib.h> as C
#import <string.h> as C
struct node { value:i64; next:node^; };
struct point { x:i32; y:i32; };

let vowels(s:cstr):i64 {
    var n = 0;
    for c in s {
        if strchr("aeiouAEIOU", c) != nullptr {
            n += 1;
        }
    }
    return n;
}

let main():i32 {
    println(vowels("Hello, Kelvin"), " ", vowels(nullptr));
    // a list: each node's pointer along next
    var c3:node = {3, nullptr};
    var c2:node = {2, &c3};
    var c1:node = {1, &c2};
    var total = 0;
    for n in &c1 {
        total += n^.value;
        n^.value *= 10;              // the node may change through n
    }
    println(total, " ", c1.value);
    // freeing nodes while walking is fine: next is read first
    var head:node^;
    for i in 1...3 {
        let n := malloc(sizeof(node)) as node^;
        n^.value = i;
        n^.next := head;
        head := n;
    }
    for n in head {
        free(n);
    }
    // arrays: up to the length, stopping early at a 0
    let xs:[i32](5) = [4, 5, 0, 6, 7];
    var sum = 0;
    for x in xs {
        sum += x;
    }
    var buf:[u8](16);
    strcpy(buf, "abc");
    var count = 0;
    for _ in buf {
        count += 1;
    }
    let pts:[struct point](2) = [{1, 2}, {3, 4}];
    var px = 0;
    for p in pts {
        px += p.x;
    }
    // pointers kelvinc cannot see, and pointers to pointers
    var lens = 0;
    for _ in getenv("NO_SUCH_VARIABLE_KELVIN") {
        lens += 1;
    }
    let words:[u8^](3) = ["one", "two", nullptr];
    for w in words {
        print(w, " ");
    }
    println(sum, " ", count, " ", px, " ", lens);
    return 0;
}
// out: 4 0
// out: 6 10
// out: one two 9 3 4 0
