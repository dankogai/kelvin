// JSON.stringify takes a borrow of the value, &j (#113)
#import <JSON>
let main():i32 {
    var j = JSON.parse("[1]")
    var s = JSON.stringify(j)
    return 0
}
// error: an owner cannot be given to a C function
