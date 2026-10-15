// OS.mkstemp gives an IO, which is the IO module's (#144, #145)
#import <OS>
let main():i32 {
    var f = OS.mkstemp("kelvin")
    return 0
}
// error: OS.mkstemp gives an IO, a module: write '#import <IO>' at the top of the file
