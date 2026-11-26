// a typealias's type ends its line (#769): ^ after it is no part of it
typealias ip = int64^
let main():int32 { return 0 }
// error: expected ';' or a new line before '^'
