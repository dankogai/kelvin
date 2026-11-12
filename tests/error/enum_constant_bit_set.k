// an enum's constant never changes (#469): setting a bit of one is an
// error, not C's
enum limit { LOW = 5, HIGH }
let main():int32 {
    LOW.bits[1] = true
    return 0
}
// error: 'LOW' is an enum's constant and cannot change; copy it into a var, as in 'var k:i32 = LOW'
