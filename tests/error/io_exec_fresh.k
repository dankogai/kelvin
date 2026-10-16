// IO.exec's fifth argument is a bool (#93)
#import <IO>
let main():int32 {
    var p = IO.exec(["env"], "r", "", [], 1)
    return 0
}
// error: the fifth argument of IO.exec is a bool: true for an environment made from nothing but the entries, false for them added to this program's
