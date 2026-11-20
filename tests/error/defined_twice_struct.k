// two structs of one name (#646): kc built it, and kelvinc left it to C
struct p { x:i64 }
struct p { y:i64 }
let main():int32 { return 0 }
// error: 'p' is struct p already (line 2), and this is struct p: a name at the top level names one thing, so name this one otherwise
