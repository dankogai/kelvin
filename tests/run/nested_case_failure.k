// a nested enum's wrong case ends the program, naming the enum by its
// path, shape.kind (#389)
struct shape {
    enum kind { round; sides: i64 }
    k:kind
}
let main():i32 {
    let a:shape = {shape.kind.round}
    println("before")
    println(a.k.sides)
    return 0
}
// out: before
// exit: 1
// err: kelvin: case 'sides' of shape.kind is not current: it is 'round'
