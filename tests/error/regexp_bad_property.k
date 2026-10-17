// the names of \p{...} are checked when kelvinc reads a $/.../ literal (#163),
// against the Unicode tables linked into it
#import <RegExp>
let main():int32 {
    let re = $/\p{Script=Klingon}+/
    return 0
}
// error: a $/.../ literal that is not a regular expression: an unknown Script in \p{...}
