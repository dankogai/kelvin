// the overlay of ovl_len with ovl_trip, for tests/project/overlay_order.k
// (#579): it is written with the other overlay's, a length over a time
// and ovl_kmh of the speed that makes, so it imports that one, and stands
// after it whichever the program imports first
#import <ovl_len>
#import <ovl_trip>
#import <ovl_len+ovl_time>
let ovl_kmh(d:ovl_len, h:f64):f64 { ovl_kmh(d / ovl_hours(h)) }
