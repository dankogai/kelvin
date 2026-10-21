// template literals (#39): `...` may span lines, and ${expression} is
// the expression's text as print shows it
#import <string.h> as C

struct point { x: int32; y: int32 }

// a template in a switch case, and in a block that a goto jumps into
let describe(n:int64) {
    switch (n) {
    case 0:
        println("zero")
        break
    default:
        println(`n is ${n}`)
    }
}
let jump(n:int64) {
    if n > 5 {
        goto big
    }
    {
        print(`small ${n}, `)
    big:
        println(`done ${n}`)
    }
}
let apply(x:int64, f:(int64):int64):int64 { f(x) }

var calls:int64 = 0
let next():int64 {
    calls += 1
    return calls
}

let greet(name:cstr) {
    println(`Hello, ${name}!`)
}

// the text lives until its block ends, also when the function returns
// early or a loop breaks
let count_up(n:int64):int64 {
    var total:int64 = 0
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

let main():int32 {
    let n:int64 = 42
    let x:float64 = 0.1
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
    println(`plain`, " ", strlen(`a${n}b`), " ", int64(`${n}${n}`) + 1, " ", count_up(5))

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
    var m:int64 = 1
    var rounds = 0
    while strlen(`${m}`) < 4 {
        m *= 10
        rounds += 1
    }
    println(s, " ", m, " ", rounds, " ", m > 5 ? `${m} items` : `none`, " ", m < 5 ? `${m} items` : `none`)

    // values of more types, as print shows them
    let tiny:float32 = 0.1
    let big:uint64 = 18446744073709551615
    let low:i128 = i128("-170141183460469231731687303715884105728")
    var letters:[int8](3) = ['h', 'i', 0]
    let ip:int8^ := &letters[0]
    let none:cstr := nullptr
    var z:int32 = 1
    let pz:int32^ := &z
    let c:uint8 = 'A'
    println(`${tiny} ${big} ${low} ${ip} ${none} ${c} ${strcmp(`${pz}`, pz.cstr) == 0}`)

    // braces, an anonymous function and a new line inside ${...}, and
    // escaped braces
    println(`${apply(2) { $0 * 10 }} ${(point){5, 6}.y} ${n +
        1} \{${n}\}`)
    return 0
}
// out: Hello, Kelvin!
// out: n = 42, n / 4.0 = 10.5, x = 0.10000000000000001, true, -7, 255, 2.5
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
// out: 0.100000001 18446744073709551615 -170141183460469231731687303715884105728 hi (null) 65 true
// out: 20 6 43 {42}
// c: char _kv_template0[sizeof "n is " + 20];
// c: char _kv_template0[sizeof "small " ", " + 20], _kv_template1[sizeof "done " + 20];
// c: KV_TEMPLATE_VALUE(_kv_build7, KV_TEMPLATE_STR, _kv_value20); KV_TEMPLATE_PART(_kv_build7, "b"); KV_TEMPLATE_TAKE(_kv_template7, _kv_build7); })
