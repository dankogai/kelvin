// math's functions of a BigFloat (#580), with <BigNum>:
// sqrt, exp, log, pow, the trigonometric and hyperbolic functions and
// their inverses, each a method too, and BigFloat.pi(). A result has
// BigFloat.precision significant bits, or the precision written, whatever
// its size: e^1000 has 128 good bits and so has e^-1000. They are a
// BigRat's functions, with as many bits after the point as that takes;
// an infinity and a NaN come where a float's function gives one
#import <BigNum>
let main():int32 {
    let one = BigFloat(1)
    let two = BigFloat(2)
    println(sqrt(two), " ", exp(one), " ", BigFloat.pi())
    println(log(two), " ", sin(one), " ", cos(one), " ", tan(one))
    println(asin(one / 2) * 6, " ", acos(one / 2) * 3, " ", atan(one) * 4, " ", atan2(one, -one) * 4 / 3)
    println(sinh(one), " ", cosh(one), " ", tanh(one))
    println(asinh(one), " ", acosh(two), " ", atanh(one / 2), " ", pow(two, one / 2) == sqrt(two))
    // to a precision, and as methods
    println(sqrt(two, 64), " ", two.sqrt(8), " ", exp(one, 16), " ", one.exp(4), " ", BigFloat.pi(8), " ", BigFloat.pi(1), " ", two.log(24))
    println(two.sqrt() == sqrt(two), " ", one.exp() == exp(one), " ", one.sin() == sin(one), " ", one.atan2(one) == atan(one), " ", two.pow(two), " ", two.pow(one / 2, 16), " ", sqrt(two, 0) == sqrt(two, 1))
    println(sqrt(two, 256), " ", sqrt(two, 256).mantissa.bits.count - 1)
    BigFloat.precision = 256
    println(BigFloat.pi())
    println(exp(BigFloat(1)))
    BigFloat.precision = 128
    // the bits are good whatever the size
    let big = exp(BigFloat(1000))
    let small = exp(BigFloat(-1000))
    println(big, " ", small, " ", big * small, " ", log(big), " ", log(small))
    let huge = exp(BigFloat(1000000))
    println(huge.exponent, " ", huge.mantissa.bits.count - 1, " ", log(huge), " ", exp(BigFloat(-1000000)).exponent, " ", sinh(BigFloat(1000000)) == huge / 2, " ", tanh(BigFloat(1000)))
    let tiny = BigFloat("1e-50")
    println(sin(tiny) == tiny, " ", tan(tiny) == tiny, " ", atan(tiny) == tiny, " ", sinh(tiny) == tiny, " ", asinh(tiny) == tiny, " ", cos(tiny), " ", exp(tiny), " ", log(one + BigFloat("1e-30")))
    println(sin(BigFloat("1e-10")), " ", log(BigFloat("1e-300")), " ", sqrt(BigFloat("1e-300")), " ", sqrt(BigFloat("1e300")), " ", atan(BigFloat("1e30")))
    println(sin(BigFloat.pi()), " ", cos(BigFloat.pi() / 2), " ", sin(BigFloat(100)), " ", cos(BigFloat("1e20")))
    // what is whole is itself
    println(sqrt(BigFloat(9)), " ", sqrt(BigFloat("0.25")), " ", pow(two, BigFloat(10)), " ", pow(BigFloat(3), BigFloat(4)), " ", pow(two, BigFloat(-1)), " ", pow(BigFloat(10), BigFloat(20)), " ", pow(BigFloat(-2), BigFloat(3)), " ", pow(BigFloat(-2), BigFloat(4)))
    println(exp(BigFloat(0)), " ", log(one), " ", sin(BigFloat(0)), " ", cos(BigFloat(0)), " ", acos(one), " ", acosh(one), " ", atan2(BigFloat(0), one), " ", atan2(BigFloat(0), -one) == BigFloat.pi())
    // sin^2 + cos^2, and each undone by its inverse
    let x = BigFloat("0.7")
    println(sin(x) * sin(x) + cos(x) * cos(x), " ", exp(log(x)), " ", log(exp(x)), " ", asin(sin(x)), " ", tan(atan(x)), " ", sqrt(x) * sqrt(x), " ", cosh(x) * cosh(x) - sinh(x) * sinh(x))
    // an infinity and a NaN, as a float's
    let inf = one / 0
    let nan = inf - inf
    println(sqrt(-one), " ", sqrt(inf), " ", log(BigFloat(0)), " ", log(-one), " ", log(inf), " ", exp(inf), " ", exp(-inf), " ", exp(nan))
    println(sin(inf), " ", atan(inf) * 2 == BigFloat.pi(), " ", atan(-inf) * 2 == -BigFloat.pi(), " ", tanh(inf), " ", tanh(-inf), " ", sinh(-inf), " ", cosh(-inf), " ", asin(two))
    println(acos(two), " ", acosh(one / 2), " ", atanh(one), " ", atanh(two), " ", pow(-two, one / 2), " ", pow(BigFloat(0), BigFloat(0)), " ", pow(BigFloat(0), -one), " ", pow(two, inf))
    println(pow(two, -inf), " ", pow(inf, two), " ", pow(nan, two), " ", exp(BigFloat("1e30")), " ", exp(BigFloat("-1e30")), " ", cosh(BigFloat("1e30")), " ", sinh(BigFloat("-1e30")), " ", tanh(BigFloat("-1e30")))
    return 0
}
// out: 1.41421356237309504880168872420969807857 2.71828182845904523536028747135266249776 3.1415926535897932384626433832795028842
// out: 0.693147180559945309417232121458176568075 0.841470984807896506652502321630298999624 0.540302305868139717400936607442976603733 1.55740772465490223050697480745836017309
// out: 3.14159265358979323846264338327950288418 3.14159265358979323846264338327950288418 3.1415926535897932384626433832795028842 3.1415926535897932384626433832795028842
// out: 1.175201193643801456882381850595600815153 1.5430806348152437784779056207570616826 0.761594155955764888119458282604793590413
// out: 0.88137358701954302523260932497979230903 1.316957896924816708625046347307968444025 0.549306144334054845697622618461262852324 true
// out: 1.414213562373095048763788073031832936977 1.4140625 2.71826171875 2.75 3.140625 4.0 0.693147182464599609375
// out: true true true true 4.0 1.414215087890625 true
// out: 1.4142135623730950488016887242096980785696718753769480731766797379907324784621 256
// out: 3.1415926535897932384626433832795028841971693993751058209749445923078164062862
// out: 2.71828182845904523536028747135266249775724709369995957496696762772407663035355
// out: 1.970071114017046993888879352243323125315e+434 5.0759588975494567652918094795743369193e-435 0.999999999999999999999999999999999999997 1000.0 -1000.0
// out: 1442568 128 1000000.0 -1442821 true 1.0
// out: true true true true true 1.0 1.0 9.99999997293605096859613807291082067707e-31
// out: 9.99999999999999999998333333333333333333e-11 -690.77552789821370520539743640530926228 1.000000000000000000000000000000000000002e-150 1e+150 1.5707963267948966192313216916387514421
// out: 1.88304107766078511674590954845603494027e-39 9.41520538830392558372954774228017470137e-40 -0.506365641109758793656557610459785432064 0.763970404441728300400146802737881122833
// out: 3.0 0.5 1024.0 81.0 0.5 100000000000000000000.0 -8.0 16.0
// out: 1.0 0.0 0.0 1.0 0.0 0.0 0.0 true
// out: 1.0 0.7 0.7 0.7 0.700000000000000000000000000000000000002 0.699999999999999999999999999999999999996 0.999999999999999999999999999999999999997
// out: nan inf -inf nan inf inf 0.0 nan
// out: nan true true 1.0 -1.0 -inf inf nan
// out: nan nan inf nan nan 1.0 inf inf
// out: 0.0 inf nan inf 0.0 inf -inf -1.0
