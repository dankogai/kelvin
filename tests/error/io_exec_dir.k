// IO.exec's directory is text or a String (#92)
#import <IO>
let main():i32 {
    var p = IO.exec(["pwd"], "r", 3)
    return 0
}
// error: the directory of IO.exec is text or a String, "" for the current one, and this is a number
