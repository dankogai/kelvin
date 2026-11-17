// math's functions of a BigFloat far from 1 (#583): a function is a
// BigRat's of BigRat(x), which is as long as x's exponent is large, so
// none makes one of such a number, where cos(BigFloat("0x1p-1000000000000"))
// was killed for want of memory. Near 0 a function is its first term, x
// or 1, and acos half of pi; far out its limit, half of pi, or ln(2x);
// out of its domain a NaN; atan2 is of the quotient; pow beside a 0 or an
// infinity reads the other's sign and size alone. A sine, a cosine and a
// tangent of a number of 2^67108864 and more are NaNs, past reckoning
#import <BigNum>
let main():int32 {
    let tiny = BigFloat("0x1p-1000000000000")
    let huge = BigFloat("0x1p+1000000000000")
    let one = BigFloat(1)
    let zero = BigFloat(0)
    let inf = one / 0
    let pi = BigFloat.pi()
    // near 0
    println(cos(tiny), " ", cosh(tiny), " ", acos(tiny) * 2 == pi, " ", acos(-tiny) * 2 == pi, " ", exp(tiny), " ", sqrt(tiny).hex, " ", log(tiny).hex)
    println(sin(tiny) == tiny, " ", tan(tiny) == tiny, " ", asin(tiny) == tiny, " ", atan(tiny) == tiny, " ", sinh(tiny) == tiny, " ", tanh(tiny) == tiny, " ", asinh(-tiny) == -tiny, " ", atanh(tiny) == tiny)
    // far out
    println(atan(huge) * 2 == pi, " ", atan(-huge) * 2 == -pi, " ", asinh(huge).hex, " ", asinh(-huge).hex, " ", acosh(huge).hex, " ", log(huge).hex)
    println(asin(huge), " ", acos(-huge), " ", atanh(huge), " ", acosh(-huge), " ", acosh(tiny), " ", log(-huge), " ", sqrt(-huge), " ", sqrt(huge).hex)
    println(exp(huge), " ", exp(-huge), " ", sinh(-huge), " ", cosh(huge), " ", tanh(-huge))
    // a sine, a cosine and a tangent are of a number below 2^67108864
    println(sin(huge), " ", cos(huge), " ", tan(-huge), " ", sin(BigFloat("0x1p+1000")), " ", cos(BigFloat("0x1p+1000"), 16), " ", tan(BigFloat("0x1p+1000"), 16))
    // atan2 is of the quotient
    println(atan2(tiny, one) == tiny, " ", atan2(tiny, -one) == pi, " ", atan2(-tiny, -one) == -pi, " ", atan2(huge, one) * 2 == pi, " ", atan2(-huge, tiny) * 2 == -pi, " ", atan2(tiny, huge).hex)
    println(atan2(huge, huge) * 4 == pi, " ", atan2(tiny, tiny) * 4 == pi, " ", atan2(-huge, huge * -3) == atan2(-one, BigFloat(-3)), " ", atan2(tiny * 3, tiny * 4) == atan2(BigFloat(3), BigFloat(4)))
    println(atan2(zero, huge), " ", atan2(zero, -huge) == pi, " ", atan2(tiny, zero) * 2 == pi, " ", atan2(inf, huge) * 2 == pi, " ", atan2(huge, inf), " ", atan2(tiny, -inf) == pi)
    // pow beside a 0 or an infinity, and of the far themselves
    println(pow(zero, huge), " ", pow(zero, -huge), " ", pow(zero, tiny), " ", pow(huge, zero), " ", pow(inf, huge), " ", pow(inf, -tiny), " ", pow(huge, inf), " ", pow(tiny, inf))
    println(pow(huge, -inf), " ", pow(tiny, -inf), " ", pow(-huge, inf), " ", pow(huge, tiny), " ", pow(huge, BigFloat(2)).hex, " ", pow(tiny, BigFloat(-1)) == huge, " ", pow(-huge, BigFloat(3)).hex, " ", pow(-huge, tiny))
    println(pow(BigFloat(2), huge), " ", pow(BigFloat(2), -huge), " ", pow(BigFloat(2), BigFloat("0x1p+40")).hex, " ", pow(huge, BigFloat("0x1p-40")).hex)
    // the limits are had where they are within the last bit: at 16 bits from 2^24, at 128 from 2^136
    BigFloat.precision = 16
    println(atan(BigFloat("0x1p+30")) * 2 == BigFloat.pi(), " ", asinh(BigFloat("0x1p+30")) == log(BigFloat("0x1p+31")), " ", cos(BigFloat("0x1p-10")), " ", cos(BigFloat("0x1p-6")), " ", acos(BigFloat("0x1p-30")) * 2 == BigFloat.pi())
    return 0
}
// out: 1.0 1.0 true true 1.0 +0x1p-500000000000 -0x1.42c5953c1fe3ff988f39be5dbce7519ep+39
// out: true true true true true true true true
// out: true true +0x1.42c5953c2146e3c87edd5d51147b1906p+39 -0x1.42c5953c2146e3c87edd5d51147b1906p+39 +0x1.42c5953c2146e3c87edd5d51147b1906p+39 +0x1.42c5953c1fe3ff988f39be5dbce7519ep+39
// out: nan nan nan nan nan nan nan +0x1p+500000000000
// out: inf 0.0 -inf inf -1.0
// out: nan nan nan -0.159201703086242438240048630820839033814 0.98724365234375 -0.161258697509765625
// out: true true true true true +0x1p-2000000000000
// out: true true true true
// out: 0.0 true true true 0.0 true
// out: 0.0 inf 0.0 1.0 inf 0.0 inf 0.0
// out: 0.0 inf nan 1.0 +0x1p+2000000000000 true -0x1p+3000000000000 nan
// out: inf 0.0 +0x1p+1099511627776 +0x1.e0de009318bafff96de6c717ef102102p+0
// out: true true 1.0 0.99988 true
