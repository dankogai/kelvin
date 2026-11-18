// IO takes a path, and a mode or none (#82, #101): three is one too many,
// as none is one too few, where kc ended itself (#610)
#import <IO>
let main():int32 {
    var f = IO("log.txt", "r", "w")
    return 0
}
// error: IO takes a path and a mode, as in IO("log.txt", "w"): text, a String or a Bytes; a path alone opens for reading (#101)
