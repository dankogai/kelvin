// two globals of one name (#646)
var g:i64 = 1
var g:i64 = 2
let main():int32 { println(g); return 0 }
// error: 'g' is a global already (line 2), and this is a global: a name at the top level names one thing, so name this one otherwise
