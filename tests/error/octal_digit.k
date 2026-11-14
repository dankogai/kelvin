// an octal number is 0o and digits of 0 to 7 (#561): an 8 is none
let main():int32 {
    let x = 0o18
    return 0
}
// error: malformed number '0o18': an octal number is 0o and digits of 0 to 7, as in 0o17
