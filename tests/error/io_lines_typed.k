// each line of f.lines is a Result<String, i64> (#406), not a String
#import <IO>
let main():int32 {
    var f = IO("/dev/null")
    for line:String in f.lines { println(line) }
    return 0
}
// error: the loop variable of .lines is a Result<String, i64>, not String
