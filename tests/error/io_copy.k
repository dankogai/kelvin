// an IO is an owner, not copied by = (#82)
#import <IO>
let main():int32 {
    var f = IO.stdout
    var g = f
    return 0
}
// error: an owner is not copied by '=' (#54)
