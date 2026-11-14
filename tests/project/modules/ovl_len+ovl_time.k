// the overlay of ovl_len with ovl_time (#551), read where both are
// imported: a length over a time is a speed, which neither module knows
// of alone
#import <ovl_len>
#import <ovl_time>
struct ovl_speed { mps: f64 }
typealias ovl_velocity = ovl_speed
extend ovl_len {
    static let /(a:Self, b:ovl_time):ovl_speed { (ovl_speed){a.m / b.s} }
}
let ovl_kmh(v:ovl_speed):f64 { v.mps * 3.6 }
