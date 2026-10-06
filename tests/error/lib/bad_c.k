// imported by tests/error/import_c_error_in_file.k: C's errors name this
// file and its lines too (#40)
#import <math.h> as C
let root():f64 { sqrt("two") }
