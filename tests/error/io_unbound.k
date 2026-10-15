// an IO an expression gives is an owner: what it holds is read through a
// variable, which frees it (#82, #109)
#import <IO>
let main():i32 {
    var b = IO("x", "r").bytes
    return 0
}
// error: '.bytes' of an IO that an expression gives: bind it to a variable first
