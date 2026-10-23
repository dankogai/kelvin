// a character's prefix is C's too (#295): u8'x', u'x', U'x', L'x'
let main():int32 {
    println(U'x')
    return 0
}
// error: U'...' is C's prefixed literal: a Kelvin source is UTF-8, and a literal's one prefix is $, a String's, $"..." (#295)
