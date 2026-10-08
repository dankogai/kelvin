// Bytes (#54): an owner on the heap; made, grown, indexed (checked),
// walked, compared, copied, moved by return and by passing, held by a
// struct, borrowed, and freed when its block ends
#import <string.h> as C
struct msg { id: i64; body: Bytes }
let greeting(name:cstr):Bytes {
    var b = Bytes("hello, ")
    b += name
    b.append('!')
    return b
}
let total(data:Bytes):i64 {           // data moves in, and is freed here
    var n = 0
    for x in data { n += i64(x) }
    return n
}
let longer(a:Bytes^, b:Bytes^):i64 { a^.count > b^.count ? i64(a^.count) : i64(b^.count) }
let main():i32 {
    var b = greeting("Kelvin")
    println(b, " ", b.count, " ", b.capacity >= b.count, " ", b.typename, " ", b.size)
    let c = b.copy()
    b.insert(0, ">> ")
    b.remove(0, 3)
    println(b == c, " ", b != c, " ", c.cstr, " ", strlen(b.cstr))
    var z = Bytes(4)
    z[1] = 7
    println(z.count, " ", z[1], " ", z[0], " ", z.capacity)
    var m:msg = {1, Bytes("body")}
    m.body += " text"
    let r := &m.body
    println(m.cstr, " ", r^.count, " ", longer(&b, &m.body))
    var sum = total(b)                // b moved out
    b = Bytes("again")                // and assigned anew
    println(sum, " ", b)
    let t:cstr := "raw"
    var d = Bytes(t)
    d += &c
    d.clear()
    d.reserve(100)
    d += "x"
    d.compact()
    println(d, " ", d.count, " ", d.capacity)
    greeting("dropped")               // a result dropped is freed
    {
        var inner = Bytes("block")
        println(inner)
    }
    return 0
}
// out: hello, Kelvin! 14 true Bytes 24
// out: true false hello, Kelvin! 14
// out: 4 7 0 16
// out: {id: 1, body: body text} 9 14
// out: 1258 again
// out: x 1 2
// out: block
// c: __attribute__((cleanup(kv_bytes_free))) kv_bytes b = KV_BYTES_OF("hello, ");
// c: return kv_bytes_take(&b);
// c: int64_t total(kv_bytes _kv_data_in)
// c: __attribute__((cleanup(kv_bytes_free))) kv_bytes data = _kv_data_in;
// c: __attribute__((cleanup(_kv_msg_free))) struct msg m = {1, KV_BYTES_OF("body")};
// c: int64_t sum = total(kv_bytes_take(&b));
// c: kv_bytes_assign(&b, KV_BYTES_OF("again"));
// c: kv_bytes_discard(greeting("dropped"));
