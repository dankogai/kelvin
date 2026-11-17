// F.zero, F.infinity and F.nan of every number of the family (#596):
// f64 and f32, where .zero is new beside the two (#546), each a constant;
// rat64 down to rat8, stored, (0/1), (1/0) and (0/0); and BigRat and
// BigFloat, computed (#595), a new one at each read, as each owns
#import <BigNum>
let none:f64 = f64.zero                               // a constant: a global's value
static_assert(f64.zero == 0.0 && f32.zero == 0.0, "zero")
let main():int32 {
    println(f64.zero, " ", f64.infinity, " ", f64.nan, " ", f32.zero, " ", f32.infinity, " ", f32.nan)
    println(f64.zero.typename, " ", f32.zero.typename, " ", none)
    println(rat64.zero, " ", rat64.infinity, " ", rat64.nan, " ", rat32.zero, " ", rat32.infinity, " ", rat32.nan)
    println(rat16.zero, " ", rat16.infinity, " ", rat16.nan, " ", rat8.zero, " ", rat8.infinity, " ", rat8.nan, " ", rat8.zero.typename)
    println(BigRat.zero, " ", BigRat.infinity, " ", BigRat.nan, " ", BigFloat.zero, " ", BigFloat.infinity, " ", BigFloat.nan)
    println(rat64.nan.isNaN, " ", rat8.infinity.isInfinite, " ", BigRat.nan.isNaN, " ", BigRat.infinity.isInfinite, " ", BigFloat.nan.isNaN, " ", BigFloat.infinity.isInfinite, " ", BigFloat.zero.isFinite)
    println(-rat64.infinity, " ", -BigRat.infinity, " ", -BigFloat.infinity, " ", BigRat.infinity.f64, " ", rat64.zero == rat64(0), " ", BigFloat.zero == BigFloat(0), " ", BigFloat.nan == BigFloat.nan)
    var x = BigFloat.zero                              // the reader's own, to change
    x = x + BigFloat(2)
    var r = BigRat.zero
    r = r + 1n.over(3n)
    println(x, " ", BigFloat.zero, " ", r, " ", BigRat.zero, " ", rat64.zero + rat64(1, 2), " ", rat64.infinity - rat64.infinity)
    return 0
}
// out: 0.0 inf nan 0.0 inf nan
// out: f64 f32 0.0
// out: (0/1) (1/0) (0/0) (0/1) (1/0) (0/0)
// out: (0/1) (1/0) (0/0) (0/1) (1/0) (0/0) rat8
// out: (0n/1n) (1n/0n) (0n/0n) 0.0 inf nan
// out: true true true true true true true
// out: (-1/0) (-1n/0n) -inf inf true true false
// out: 2.0 0.0 (1n/3n) (0n/1n) (1/2) (0/0)
