// JSON.stringify's replacer (#113): a function (key:cstr, value:const
// JSON^):JSON? called for the root with "", each member with its key and
// each element with its index as text; what it gives is written, none
// leaves a member out and writes null for an element, as JS's undefined
#import <JSON>
#import <string.h> as C
let noSecrets(key:cstr, v:const JSON^):JSON? {
    if strcmp(key, "password") == 0 { return none }          // a cstr compares by its text with strcmp
    if v^.is(number) { return JSON.number(v^.number * 2.0) }
    return v^.copy()
}
let onlyStrings(key:cstr, v:const JSON^):JSON? {
    if v^.is(string) || v^.is(array) || v^.is(object) || key[0] == 0 { return v^.copy() }
    return none
}
let main():i32 {
    var j = JSON.parse("{\"user\": \"ann\", \"password\": \"hunter2\", \"age\": 21, \"scores\": [1, 2, \"x\"]}")
    var a = JSON.stringify(&j, noSecrets)
    println(a)
    var b = JSON.stringify(&j, onlyStrings, " ")
    println(b)
    var unit = $"--"
    var c = JSON.stringify(&j, noSecrets, &unit)
    println(c)
    var gone = JSON.stringify(&j, { (key:cstr, v:const JSON^):JSON? in none })   // the root left out: no text at all (#114)
    println(gone.count, " [", gone, "]")
    return 0
}
// out: {"user":"ann","age":42,"scores":[2,4,"x"]}
// out: {
// out:  "user": "ann",
// out:  "password": "hunter2",
// out:  "scores": [
// out:   null,
// out:   null,
// out:   "x"
// out:  ]
// out: }
// out: {
// out: --"user": "ann",
// out: --"age": 42,
// out: --"scores": [
// out: ----2,
// out: ----4,
// out: ----"x"
// out: --]
// out: }
// out: 0 []
