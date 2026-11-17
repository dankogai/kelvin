// A part of a CBF's exp is a product, e^x times a cosine or a sine, and
// it is the product that is tried against the exponents there are (#589),
// with <math> and <BigFloat>: exp(CBF(7000000000000000000, tiny)), tiny
// being 2^-4000000000000000000, has an imaginary part of
// 2^6098865286222743851, where it was an infinity. e^x was made a
// BigFloat first, an infinity past any exponent and 0 below the least,
// and a part was of that; now e^x is kept with its exponent in full. So
// are sinh and cosh, half of e^|x|, in sinh, cosh, sin and cos, the
// e^(-2|a|) that tanh and tan are of far out, and the e^x of pow. e^x was
// had to 16 bits more than are asked, and was 0 where those were below the
// least exponent: so a part 16 places above the least number was 0 too.
// And tanh's e^(-2|a|) was of 2|a| rounded to BigFloat.precision
#import <math>
#import <BigFloat>
let main():int32 {
    let far = BigFloat("7000000000000000000")
    let tiny = BigFloat("0x1p-4000000000000000000")
    let quarter = BigFloat.pi() / 2
    // e^x past any exponent, times a sine that brings it back
    println(exp(CBF(far, tiny)).hex)
    println(sinh(CBF(far, tiny)).hex, " ", cosh(CBF(-far, tiny)).hex)
    println(sin(CBF(tiny, far)).hex, " ", cos(CBF(tiny, -far)).hex)
    // beside a quarter turn it is the cosine that does: pi / 2 to 128 bits is not pi / 2
    println(exp(CBF(BigFloat("6393154322601327940"), quarter)).hex, " ", cosh(CBF(BigFloat("6393154322601327940"), quarter)).hex)
    // all but below the least number: both parts were 0
    println(exp(CBF(BigFloat("-6393154322601327735"), BigFloat(1))).hex)
    // tanh far out is 1 and 4 sin b cos b e^(-2|a|), and tan is of it
    println(tanh(CBF(BigFloat("3196577161300663870"), BigFloat(1))).hex, " ", tan(CBF(BigFloat(1), BigFloat("-3196577161300663870"))).hex)
    // its e^(-2|a|) is of 2|a| itself, of an a of more bits than BigFloat.precision too
    let wide = BigFloat("0x1.00000000000000000000000000000000001p+40", 200)
    println(tanh(CBF(wide, BigFloat(1))).hex)
    // pow is e^(w log z): 2^w, and w tiny / 2 times it
    println(pow(CBF(BigFloat(2), tiny), CBF(BigFloat("0x1.1p+63"))).hex)
    // to a precision, and a method
    println(exp(CBF(far, tiny), 53).hex, " ", CBF(far, tiny).exp(16).hex, " ", exp(CBF(far, tiny), 200).hex)
    // past them still: an x of 2^64, and a product that is past too
    println(exp(CBF(BigFloat("0x1p+64"), tiny)), " ", exp(CBF(-BigFloat("0x1p+64"), tiny)), " ", exp(CBF(far, BigFloat(1))), " ", exp(CBF(-far, BigFloat(1))))
    // a sine not known makes a NaN, but 0 where e^x is 0
    let huge = BigFloat("0x1p+1000000000000")
    println(exp(CBF(far, huge)), " ", exp(CBF(-far, huge)), " ", sinh(CBF(far, huge)), " ", tanh(CBF(far, huge)))
    // parts that are far from the edges are what they were
    println(exp(CBF(BigFloat(1), BigFloat(2))).hex, " ", sinh(CBF(BigFloat(40), BigFloat(2))).hex)
    return 0
}
// out: (+inf+0x1.6ef55a9ee10e1b877027dd336cb404fep+6098865286222743851.i)
// out: (+inf+0x1.6ef55a9ee10e1b877027dd336cb404fep+6098865286222743850.i) (+inf-0x1.6ef55a9ee10e1b877027dd336cb404fep+6098865286222743850.i)
// out: (+0x1.6ef55a9ee10e1b877027dd336cb404fep+6098865286222743850+inf.i) (+inf+0x1.6ef55a9ee10e1b877027dd336cb404fep+6098865286222743850.i)
// out: (+0x1.277472a41fa283e0c245a4baf59573c8p+9223372036854775837+inf.i) (+0x1.277472a41fa283e0c245a4baf59573c8p+9223372036854775836+inf.i)
// out: (+0x1.02bf2abb47b825eba3f7a341a97d0e6p-9223372036854775672+0x1.92f963e6849c3b65410994c385aaa6c6p-9223372036854775672.i)
// out: (+0x1p+0+0x1.778fdca7793dc31adf5d798045f111c4p-9223372036854775678.i) (+0x1.778fdca7793dc31adf5d798045f111c4p-9223372036854775678-0x1p+0.i)
// out: (+0x1p+0+0x1.673a5de67307ff4862219e256203c604p-3172519945584.i)
// out: (+inf+0x1.1p+5799832789158199358.i)
// out: (+inf+0x1.6ef55a9ee10e2p+6098865286222743851.i) (+inf+0x1.6ef6p+6098865286222743851.i) (+inf+0x1.6ef55a9ee10e1b877027dd336cb404fea776abc6e6616f636ep+6098865286222743851.i)
// out: (inf+inf.i) (0.0+0.0.i) (inf+inf.i) (0.0+0.0.i)
// out: (nan+nan.i) (0.0+0.0.i) (nan+nan.i) (1.0+0.0.i)
// out: (-0x1.21969c4953cd175c9e45e7c3c99adfdap+0+0x1.3c618a2274afd5ad718e5e06d765dc58p+1.i) (-0x1.5c016716611d835b871c3a9a1b2c2348p+55+0x1.7c33f2b8b1763a37b481d483b18aba48p+56.i)
