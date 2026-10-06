// imported by tests/run/import_boundary.k: its "helper.h" is the one
// next to it (#40)
#import "helper.h" as C
let add3(a:i32, b:i32, c:i32):i32 { helper_add(helper_add(a, b), c) }
