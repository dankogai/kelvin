// operators a struct defines (#42): let +(a:T, b:U):R { ... } and others,
// called where a Kelvin struct is an operand, as functions of their types
// are (#41); numbers keep C's own operators (tests/run/operators.k)
#import <math.h> as C
#import <stdlib.h> as C

struct money;
// for a struct declared without its body yet, as for a function
let +(a:money, b:money):money
struct money { cents: i64 }

// a value may go on with an annotated operand on the next line, and a
// definition starts with let (#45)
let rate:f64 = (3:f64)
    / (2:f64)
let +(var a:money, n:i64):money {
    a.cents += n
    return a
}
let half(a:money):money
let *(a:money, k:i64):money { (money){a.cents * k} }
let -(a:money, b:money):money { (money){a.cents - b.cents} }
let -(a:money):money { (money){-a.cents} }
let *(k:i64, a:money):money { a * k }
let *(a:money, x:f64):money { (money){i64(round(f64(a.cents) * x))} }
let /(a:money, k:i64):money { (money){a.cents / k} }
let %(a:money, k:i64):money { (money){a.cents % k} }
let ==(a:money, b:money):bool { a.cents == b.cents }
let !=(a:money, b:money):bool { !(a == b) }
let <(a:money, b:money):bool { a.cents < b.cents }
let <=(a:money, b:money):bool { !(b < a) }
let >(a:money, b:money):bool { b < a }
let >=(a:money, b:money):bool { !(a < b) }
let +(a:money, b:money):money { (money){a.cents + b.cents} }
let half(a:money):money { a / 2 }

// a union may define operators too
union bits { u: u64; f: f64 }
let ==(a:bits, b:bits):bool { a.u == b.u }

let main():i32 {
    let a:money = {150}
    let b:money = {275}
    println((a + b).cents, " ", (b - a).cents, " ", (-a).cents, " ", (a * 3).cents, " ", (2 * a).cents, " ", (a * rate).cents)
    println((b / 2).cents, " ", (b % 100).cents, " ", a == b, " ", a != b, " ", a < b, " ", a <= a, " ", a > b, " ", b >= a)

    // C's precedence, a result is an operand in turn, and a literal has its
    // type, also negated
    println((a + b * 2).cents, " ", (-(a - b) * 2).cents, " ", a + b == (money){425}, " ", `${(a + 5).cents}`, " ",
            (a * -2).cents, " ", (a * -0.5).cents, " ", half(b).cents)

    // x op= y is x = x op y
    var m:money = a
    m += b
    m *= 2
    m -= (money){50}
    m %= 300
    m /= 2
    var ms:money[2] = {a, b}
    let i:i64 = 1
    ms[i] += a
    ms[i - 1] += 1
    println(m.cents, " ", ms[0].cents, " ", ms[1].cents)

    // where only C sees the other operand's type, _Generic chooses, and a
    // number of another type converts to the one operator that takes a
    // number there
    println((a * round(1.5)).cents, " ", (a + abs(-5)).cents, " ", (a / abs(-3)).cents, " ", (abs(-2) * a).cents,
            " ", (a * labs(-2)).cents, " ", (a * llabs(-2)).cents)
    let one:bits = {.f = 1.0}
    println(one == one, " ", one == (bits){.u = 0})
    return 0
}
// out: 425 125 -150 450 300 225
// out: 137 75 false true true true false true
// out: 700 250 true 155 -300 -75 137
// out: 100 151 425
// out: 300 155 50 300 300 300
// out: true false
// c: struct money _kv_add_op__money__money(const struct money a, const struct money b)
// c: struct money _kv_neg_op__money(const struct money a)
// c: __attribute__((warn_unused_result)) bool _kv_le_op__money__money(const struct money a, const struct money b)
// c: _Generic((_kv_self1), struct money: _kv_add_op__money__money, default: __builtin_choose_expr(KV_NUMBER(_kv_self1) == KV_N_I64, _kv_add_op__money__i64, __builtin_choose_expr(KV_NUMBER(_kv_self1) != 0, _kv_add_op__money__i64, kv_no_such_operator)))(_kv_a_self1, _kv_self1)
