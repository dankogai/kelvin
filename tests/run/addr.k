// p.addr and p.hex (#37): a pointer's or a function's address as a
// uintptr_t, and as text, 0x and all the digits
#import <errno.h> as C
#import <stdint.h> as C
#import <stdlib.h> as C
#import <string.h> as C
#import "include/fields.h" as C

struct host { addr: u32; port: u16 }
struct pair { x: i32; y: i32 }
let point_of(x:i32, y:i32):pair { (pair){x, y} }

let square(x:i64):i64 { x * x }
let where(p:i32^):uintptr_t { p.addr }      // a number, which may be returned

let main():i32 {
    var x:i32 = 7
    let p:i32^ := &x
    let s:cstr := "abc"
    let q:any^ := nullptr
    let width:u64 = 2 + 2 * sizeof(any^)    // 0x and two digits a byte

    // .addr is the address as a number
    println(p.addr == p as uintptr_t, " ", s.addr == s as uintptr_t, " ", q.addr, " ", nullptr.addr, " ",
            p.next.addr - p.addr == sizeof(i32))

    // .hex is 0x and all the digits, which #36 reads back
    println(strlen(p.hex) == width, " ", strlen(q.hex) == width, " ", u64(p.hex, 16) == p.addr, " ",
            u64(s.hex, 16) == s.addr, " ", strncmp(p.hex, "0x", 2) == 0, " ", u64(nullptr.hex, 16))

    // functions and function values
    let f:(i64):i64 := square
    println(f.addr == square.addr, " ", square.addr != 0, " ", u64(f.hex, 16) == f.addr, " ",
            u64({ (n:i64):i64 in n + 1 }.hex, 16) != 0)

    // a pointer kelvinc cannot see
    let b:cstr := strchr(s, 'b')
    println(u64(strchr(s, 'b').hex, 16) == b.addr, " ", strlen(strchr(s, 'b').hex) == width)

    // .addr is unsigned and as wide as a pointer; .hex has lowercase digits
    let digits:cstr := p.addr.hex
    println(nullptr.addr - 1 > 0, " ", p.addr.size == sizeof(any^), " ", strspn(p.hex + 2, "0123456789abcdef") ==
            width - 2, " ", strncmp(digits, "0x", 2) == 0, " ", where(p) == p.addr)

    // pointers kelvinc sees by their shape: a string, &x of a C name, a
    // step, a ?:, and text, which is u8^
    let n:i64 = 255
    let t:cstr := n.hex
    println("abc".addr != 0, " ", strlen("abc".hex) == width, " ", (&errno).addr == &errno as uintptr_t, " ",
            (p + 1).addr - p.addr == sizeof(i32), " ", (n > 0 ? p : nullptr as i32^).addr == p.addr, " ",
            n.hex.addr != 0, " ", strlen(t.hex) == width)

    // a compound literal's member keeps its own .hex and .typename, also
    // of a C type kelvinc cannot see
    println(point_of(1, 2).y.hex, " ", (pair){1, 2}.y.hex, " ", (div_t){.quot = 3, .rem = 1}.quot.hex, " ",
            (div_t){.quot = 3, .rem = 1}.quot.typename)

    // a field named addr wins: a Kelvin struct's, a C struct's, and one
    // kelvinc cannot see is no struct
    let h:host = {0x7f000001, 80}
    var pl:struct place = {3}
    var pt:place_t = {4}
    println(h.addr, " ", pl.addr, " ", pt.addr)
    return 0
}
// out: true true 0 0 true
// out: true true true true true 0
// out: true true true true
// out: true true
// out: true true true true true
// out: true true true true true true true
// out: +0x2 +0x2 +0x3 i32
// out: 2130706433 3 4
