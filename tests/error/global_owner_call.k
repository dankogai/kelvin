// a global owner (#178): C initializes a global with a constant alone, and
// an owner is made by a call, so kelvinc says so, instead of C
#import <RegExp>
let re = $/(\d+)F/g
let main():int32 {
    return 0
}
// error: 're' is a global struct RegExp, which C initializes with a constant alone, and an owner is made by a call: declare it with its type, 'var re:struct RegExp', and give it its value in main or another function
