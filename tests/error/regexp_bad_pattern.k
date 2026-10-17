// a $/.../ literal is checked when kelvinc reads it (#163): a pattern that
// is not JS's is an error at the place in the pattern, before anything runs
#import <RegExp>
let main():int32 {
    let re = $/(\d+-(?<m>\d\d)/g
    return 0
}
// error: a $/.../ literal that is not a regular expression: unmatched (
