// error: 'count' is a computed attribute of point already: one name is an attribute of a type, read as point.count, or a function of it, called
// one name is a computed attribute of a type or a function of it (#595)
struct point { x: int64 }
extend point {
    static let count:int64 { 2 }
    static let count():int64 { 3 }
}
let main():int32 { return 0 }
