// alignas(N) and alignas(T) (#396), C23's name, before the declaration of
// a variable, a global, a static or a member, where static and inline go:
// C's _Alignas; each name of a declaration takes it
struct block {
    tag: u8
    alignas(16) data: [u8](32)
    alignas(f64) n: i32
}
alignas(64) var line:[u8](64)
static alignas(32) var pad:i64 = 7
let main():i32 {
    alignas(16) var buf:[u8](48)
    alignas(8) let k:i32 = 5, j:i32 = 6
    var b:block
    println((&buf[0]).addr % 16 == 0, " ", (&line[0]).addr % 64 == 0, " ", (&pad).addr % 32 == 0, " ", pad)
    println(k, " ", j, " ", (&k).addr % 8 == 0, " ", (&j).addr % 8 == 0, " ", b.size, " ", (&b.data[0]).addr % 16 == 0, " ", b.align)
    return 0
}
// out: true true true 7
// out: 5 6 true true 64 true 16
// c:     _Alignas(16) uint8_t data[32];
// c:     _Alignas(double) int32_t n;
// c: _Alignas(64) uint8_t line[64];
// c: static _Alignas(32) int64_t pad = 7;
// c:     _Alignas(8) const int32_t j = 6;
