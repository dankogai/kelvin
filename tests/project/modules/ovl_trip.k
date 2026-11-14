// a module that imports ovl_time, for tests/project/overlay_nested.k (#551)
#import <ovl_time>
let ovl_hours(h:f64):ovl_time { ovl_time(h * 3600.0) }
