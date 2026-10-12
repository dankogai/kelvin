// OS's members (#94)
let main():i32 {
    OS.reboot()
    return 0
}
// error: OS has cwd, chdir(path), env(name), setenv(name, value), unsetenv(name), exists(path), isdir(path), isfile(path), remove(path), rename(from, to), mkdir(path), rmdir(path), listdir(path), system(command) and pid, not 'reboot'
