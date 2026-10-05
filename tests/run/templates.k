// template literals (#39): `...` may span lines, and ${expression} is
// the expression's text as print shows it
#import <string.h> as C

struct point { x: i32; y: i32 }

// a template in a switch case, and in a block that a goto jumps into
describe(n:i64) {
    switch (n) {
    case 0:
        println("zero")
        break
    default:
        println(`n is ${n}`)
    }
}
jump(n:i64) {
    if n > 5 {
        goto big
    }
    {
        print(`small ${n}, `)
    big:
        println(`done ${n}`)
    }
}
apply(x:i64, f:(i64):i64):i64 { f(x) }

var calls:i64 = 0
next():i64 {
    calls += 1
    return calls
}

greet(name:cstr) {
    println(`Hello, ${name}!`)
}

// the text lives until its block ends, also when the function returns
// early or a loop breaks
count_up(n:i64):i64 {
    var total:i64 = 0
    for i in 0..<10 {
        let text:cstr := `${i}`
        if i == n {
            break
        }
        total += strlen(text)
    }
    if total > 100 {
        return -1
    }
    return total
}

main():i32 {
    let n:i64 = 42
    let x:f64 = 0.1
    let p:point = {3, 4}
    greet("Kelvin")
    println(`n = ${n}, n / 4.0 = ${n / 4.0}, x = ${x}, ${n > 40}, ${-7:i8}, ${255:u8}, ${2.5:f32}`)
    println(`p = ${p}, sum = ${p.x + p.y}, hex = ${n.hex}, nested = ${`[${n + 1}]`}`)

    // lines, quotes and escapes
    let multi:cstr := `one
  two "three" \`four\` \${five} $six {seven}
eight\
nine\tten`
    println(multi)

    // with no ${...}, a template is a plain string literal
    println(`plain`, " ", strlen(`a${n}b`), " ", i64(`${n}${n}`) + 1, " ", count_up(5))

    // each evaluation makes its text again
    for i in 0..<3 {
        print(`<${i}:${i * i}>`)
    }
    println()

    // values are evaluated once each, left to right
    println(`${next()} ${next()} ${next()}`)

    describe(0)
    describe(7)
    jump(1)
    jump(9)

    // each evaluation replaces the text, and a value may read the
    // earlier text of the same template
    var s:cstr := "a"
again:
    s := `${s}b`
    if strlen(s) < 4 {
        goto again
    }
    var m:i64 = 1
    var rounds = 0
    while strlen(`${m}`) < 4 {
        m *= 10
        rounds += 1
    }
    println(s, " ", m, " ", rounds, " ", m > 5 ? `${m} items` : `none`, " ", m < 5 ? `${m} items` : `none`)

    // values of more types, as print shows them
    let tiny:f32 = 0.1
    let big:u64 = 18446744073709551615
    let low:i128 = i128("-170141183460469231731687303715884105728")
    var letters:i8[3] = {'h', 'i', 0}
    let ip:i8^ := &letters[0]
    let none:cstr := nullptr
    var z:i32 = 1
    let pz:i32^ := &z
    let c:u8 = 'A'
    println(`${tiny} ${big} ${low} ${ip} ${none} ${c} ${strcmp(`${pz}`, pz.cstr) == 0}`)

    // braces, an anonymous function and a new line inside ${...}, and
    // escaped braces
    println(`${apply(2) { $0 * 10 }} ${(point){5, 6}.y} ${n +
        1} \{${n}\}`)
    return 0
}
// out: Hello, Kelvin!
// out: n = 42, n / 4.0 = 10.5, x = 0.1, true, -7, 255, 2.5
// out: p = {x: 3, y: 4}, sum = 7, hex = +0x2a, nested = [43]
// out: one
// out:   two "three" `four` ${five} $six {seven}
// out: eightnine	ten
// out: plain 4 4243 5
// out: <0:0><1:1><2:4>
// out: 1 2 3
// out: zero
// out: n is 7
// out: small 1, done 1
// out: done 9
// out: abbb 1000 3 1000 items none
// out: 0.1 18446744073709551615 -170141183460469231731687303715884105728 hi (null) 65 true
// out: 20 6 43 {42}
// c: __attribute__((cleanup(kv_template_free))) kv_template _kv_template0 = {0};
