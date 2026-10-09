// switch (#63): no parentheses needed, a case ends at the next (no
// break, no fallthrough; break leaves the switch), case a, b: shares a
// body, and every value is handled: every case of an enum with values,
// every enumerator of an enum, or default:
enum color { red, green, blue }
enum shape { none; circle: f64; rect: {w:f64, h:f64} }
let name(c:color):cstr {
    switch c {
    case red: return "red"
    case green, blue: return "greenish"
    }
}
let area(s:shape):f64 {
    switch s {
    case none: return 0.0
    case circle: return 3.0 * s.circle * s.circle
    case rect: return s.rect.w * s.rect.h
    }
}
let main():i32 {
    for n in 0..<5 {
        switch n {
        case 0:
            print("zero ")
        case 1, 2:
            print("small ")
            if n == 2 { break }
            print("one ")
        case 3:
            continue
        default:
            print("big ")
        }
        print("| ")
    }
    println()
    println(name(red), " ", name(blue), " ", area(shape.circle(1.0)), " ", area((shape){.rect = {2.0, 3.0}}))
    var k = 4
    switch (k) {
    case 4:
        println("four")
    default:
        break
    }
    switch k { default: println("only default") }
    switch k { case 4: println("four again"); default: }
    return 0
}
// out: zero | small one | small | big | 
// out: red greenish 3.0 6.0
// out: four
// out: only default
// out: four again
// c: case green:
// c: case blue:
// c: __builtin_unreachable();
