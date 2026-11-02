// error: 'nullptr' is 'nowhere' in Kelvin (#446), a pointer to nothing, as 'none' is an Optional with nothing: write 'nowhere'
let main():int32 { var p:int32^ := nullptr; return p.isNull ? 0 : 1 }
