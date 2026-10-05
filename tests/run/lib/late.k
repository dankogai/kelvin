twice_late(n:i64):i64 { n * 2 }
// imported by tests/run/import_boundary.k (#40): its first line comes
// after a line of a smaller number in the importing file, and its last
// declaration, a let, on a line of a larger number than what follows
// the import there. The end of each file still ends a declaration.
//
//
//
//
//
//
let LATE = 4
