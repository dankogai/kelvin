// template literals (#39): `...` may span lines, and ${expression} is
// the expression's text as print shows it
#import <string.h> as C

struct point { x: i32; y: i32 }

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
