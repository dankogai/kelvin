// x op= y changes the value its first parameter points to (#518): a
// Self, not a Self^, is an error
struct Acc { total: i64 }
extend Acc {
    static let +=(a:Self, b:i64) { }
}
let main():int32 { return 0 }
// error: '+=' changes the value its first parameter points to: write 'static let +=(a:T^, b:U)', T a Kelvin struct or union (#518)
