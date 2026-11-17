// error: 'count' is a stored attribute of point already, 'static let point.count = ...': an attribute of a type is stored or computed, not both
// one name is a stored attribute of a type or a computed one (#595)
struct point { x: int64 }
extend point {
    static let count:int64 = 1
    static let count:int64 { 2 }
}
let main():int32 { return 0 }
