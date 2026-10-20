// JSON.stringify takes a borrow of the value, &j (#113)
#import <JSON>
let main():int32 {
    var j = JSON.parse("[1]")
    var s = JSON.stringify(j)
    return 0
}
// error: JSON.stringify(...) takes a borrow of JSON here: pass '&j'
