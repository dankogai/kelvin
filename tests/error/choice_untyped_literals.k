// a choice of two numbers written, in a declaration of no type written
// (#777): kelvinc infers a choice's type of two values of one type it
// sees, and a literal's is its context's; kc built it
let main():int32 {
    var q = true ? 1 : 2
    return 0
}
// error: 'q' needs a type: write 'q:T = ...' (or 'q:T := ...' for a reference)
