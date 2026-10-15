// write takes a borrow of a String or a Bytes, not the owner itself (#82)
#import <IO>
let main():i32 {
    var f = IO.stdout
    var s = $"text"
    f.write(s)
    return 0
}
// error: '.write' takes a borrow of a String, '&s'
