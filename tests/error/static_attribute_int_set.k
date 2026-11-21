// error: 'u8.top' is computed, and never set: a stored attribute, 'static var u8.top = v', is
// an integer type's computed attribute has no setter (#668)
extend u8 { static let top:u8 { 255 } }
let main():int32 {
    u8.top = 3
    return 0
}
