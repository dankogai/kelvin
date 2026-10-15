// OS is a module (#145): a program imports it
let main():i32 {
    println(OS.pid())
    return 0
}
// error: OS is a module: write '#import <OS>' at the top of the file
