// IO.pipe takes nothing (#87)
#import <IO>
let main():int32 {
    var p = IO.pipe("r")
    return 0
}
// error: IO.pipe takes nothing, and gives {reader: IO, writer: IO}
