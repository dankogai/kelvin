// error: 'i64.answer' is an attribute of the type: read it as 'i64.answer', with no parentheses
// an integer type's computed attribute is read, not called (#668)
static let i64.answer:i64 { 42 }
let main():int32 {
    println(int64.answer())
    return 0
}
