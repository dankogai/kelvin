// print of a complex number (#570): (a+b.i), its .string, where a struct's
// derived text was, {real: a, imag: b}; a c64's and a c32's parts as print
// writes a float, the imaginary part's sign joining the two, both parts
// always and a zero with its sign; a CBR's parts each a BigRat's text, a +
// between them; the type reads it back, c64(z.cstr) is z
#import <math>
#import <Rational>
struct holder { name: cstr; z: c64; w: c32 }
struct exact { q: CBR }
let main():int32 {
    let z = c64(1.5, -2.0)
    let q = CBR(1n.over(2n), (-1n).over(3n))
    // print, .cstr, .string and a template show the same text
    println(z, " ", z.conj(), " ", z.cstr, " ", z.string, " ", `<${z}>`, " ", $`<${z}>`, " ", z.string.typename)
    // both parts always, a zero with its sign
    println(c64(1.5, 0.0), " ", c64(0.0, 2.0), " ", c64(1.5, -0.0), " ", c64(-0.0, 2.0), " ", c64(0.0, 0.0), " ", c64(-0.0, -0.0), " ", c64(0.0, -0.0))
    // a nan has no sign, so a + joins it; each part is print's f64
    println(c64(f64.nan, f64.nan), " ", c64(f64.infinity, -f64.infinity), " ", c64(1e300, -1e-300), " ", c64(0.1, 1.0 / 3.0))
    // a c32, of its f32 parts
    let w = c32(0.1:f32, -2.0:f32)
    println(w, " ", w.cstr, " ", `${w}`, " ", c32(0.0:f32, -0.0:f32), " ", c32(f32.nan, f32.infinity), " ", w.string.typename)
    // the type reads it back, and it pastes back as the number
    println(c64(z.cstr) == z, " ", c64(&z.string) == z, " ", c32(w.cstr) == w, " ", c64(c64(-0.0, -0.0).cstr), " ", c64(c64(f64.infinity, -f64.infinity).cstr))
    println((1.5-2.0.i) == z, " ", (1.5-2.0.i).typename)
    // an element and a member are shown so too
    let zs = [z, 1.0.i]
    let h = (holder){"h", z, w}
    println(zs, " ", h)
    // a CBR: each part a BigRat's text, in its own parentheses
    println(q, " ", q.conj(), " ", q.cstr, " ", `<${q}>`, " ", q.string.typename)
    println(CBR(3, -4), " ", CBR(0), " ", CBR(0) / CBR(0), " ", 1n.over(7n).i)
    println(CBR(q.cstr) == q, " ", CBR(&q.string) == q, " ", CBR($`${q}`.cstr) == q)
    let e = (exact){q.copy()}
    println(e)
    // of any length, shown whole
    let big = CBR(BigInt(7).pow(200), BigInt(3).pow(200))
    println(big)
    println(big.string.count, " ", CBR(&big.string) == big)
    // .hex and .dec are as they were
    println(z.hex, " ", z.dec, " ", q.hex)
    return 0
}
// out: (1.5-2.0.i) (1.5+2.0.i) (1.5-2.0.i) (1.5-2.0.i) <(1.5-2.0.i)> <(1.5-2.0.i)> String
// out: (1.5+0.0.i) (0.0+2.0.i) (1.5-0.0.i) (-0.0+2.0.i) (0.0+0.0.i) (-0.0-0.0.i) (0.0-0.0.i)
// out: (nan+nan.i) (inf-inf.i) (1.0000000000000001e+300-1e-300.i) (0.10000000000000001+0.33333333333333331.i)
// out: (0.100000001-2.0.i) (0.100000001-2.0.i) (0.100000001-2.0.i) (0.0-0.0.i) (nan+inf.i) String
// out: true true true (-0.0-0.0.i) (inf-inf.i)
// out: true c64
// out: [(1.5-2.0.i), (0.0+1.0.i)] {name: "h", z: (1.5-2.0.i), w: (0.100000001-2.0.i)}
// out: ((1n/2n)+(-1n/3n).i) ((1n/2n)+(1n/3n).i) ((1n/2n)+(-1n/3n).i) <((1n/2n)+(-1n/3n).i)> String
// out: ((3n/1n)+(-4n/1n).i) ((0n/1n)+(0n/1n).i) ((0n/0n)+(0n/0n).i) ((0n/1n)+(1n/7n).i)
// out: true true true
// out: {q: ((1n/2n)+(-1n/3n).i)}
// out: ((10461838291314357175018899611816813659819188550170233659950140084035125767424262251774382614909364050293065248252546314174063180343683591188150754267339816534637456120001n/1n)+(265613988875874769338781322035779626829233452653394495974574961739092490901302182994384699044001n/1n).i)
// out: 283 true
// out: (+0x1.8p+0-0x1p+1.i) (+1.5-2.0.i) ((+0x1n/0x2n)+(-0x1n/0x3n).i)
