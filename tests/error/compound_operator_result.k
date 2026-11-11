// x op= y changes x in place and gives nothing (#518)
struct Acc { total: i64 }
let +=(a:Acc^, b:i64):Acc {
    a^.total += b
    return a^
}
let main():int32 { return 0 }
// error: '+=' changes the value a points to and gives nothing: drop its result type
