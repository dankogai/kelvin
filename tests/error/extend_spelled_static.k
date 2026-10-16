// a type with no tag has no name to read a type attribute by (#133)
enum { nothing; just: int64 }
extend enum{nothing, just: int64} {
    static let zero = 0
}
let main():int32 { return 0 }
// error: a type attribute is read by the type's name, as T.x, and a type with no tag has none
