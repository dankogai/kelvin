// a case of an enum with values that holds its own enum (#659)
enum tree { leaf; node: tree }
let main():int32 { return 0 }
// error: 'node' makes tree hold itself, and a value that holds itself has no size: hold it by a pointer, tree^, or in an Array<tree>
