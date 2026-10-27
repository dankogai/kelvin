// static_assert(cond) and static_assert(cond, "message") (#394), C23's
// name: C's _Static_assert, at the top level and in a block, which the C
// compiler judges as it compiles; with no message, the condition as written
struct point { x:i32, y:i32 }
enum color { red, green, blue }
static_assert(sizeof(i64) == 8, "i64 is eight bytes")
static_assert(sizeof(point) == 8)
static_assert(blue == 2)
let main():i32 {
    static_assert(sizeof(u8) == 1, "u8 " "is a byte")
    var p:point = {1, 2}
    static_assert(p.size == 8)
    println(p, " ok")
    return 0
}
// out: {x: 1, y: 2} ok
// c: _Static_assert(sizeof(int64_t) == 8, "i64 is eight bytes");
// c: _Static_assert(sizeof(struct point) == 8, "sizeof(point) == 8");
// c: _Static_assert(blue == 2, "blue == 2");
// c:     _Static_assert(sizeof(uint8_t) == 1, "u8 " "is a byte");
// c:     _Static_assert(sizeof(p) == 8, "p.size == 8");
