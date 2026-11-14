// a module for tests/project/overlay*.k (#551): a time, in seconds
struct ovl_time { s: f64 }
let ovl_time(s:f64):ovl_time { (ovl_time){s} }
