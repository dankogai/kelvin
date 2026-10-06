// error: kelvinc cannot see its fields, so it cannot follow a next field
#import <time.h> as C
struct tm;
let main():i32 {
    var t:tm^;
    for x in t {
    }
    return 0;
}
