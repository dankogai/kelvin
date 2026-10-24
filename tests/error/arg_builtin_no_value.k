// error: this has no value, so it cannot be argument 1 of 'println': make the call alone, as a line of its own
// nor is a built-in method with no value, an IO's print (#316)
#import <IO>
let main():int32 {
    var f:IO = IO.stdout
    println(f.print("x"))
    return 0
}
