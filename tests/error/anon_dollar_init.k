// error: there, '{' starts an initializer list, so an anonymous function writes its parameters
main():i32 {
    let f := { $0 + 1 };
    return 0;
}
