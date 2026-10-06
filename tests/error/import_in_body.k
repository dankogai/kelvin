// #import is for the top level (#40)
let main():i32 {
    #import "lib/bad.k"
    return 0
}
// error: import_in_body.k:3:5: error: #import is for the top level of a file, outside functions, structs and blocks
