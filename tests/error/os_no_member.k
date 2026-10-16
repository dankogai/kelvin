// OS's members (#94)
#import <OS>
let main():int32 {
    OS.reboot()
    return 0
}
// error: OS has no 'reboot': see documents/os.md for cwd, chdir, env, setenv, unsetenv, exists, isdir, isfile, islink, remove, unlink, rename, mkdir, makedirs, rmdir, listdir, stat, lstat, symlink, readlink, link, chmod, truncate, realpath, basename, dirname, join, system, kill, umask, pid, ppid, uid, gid, user, host, time, sleep, tmpdir, walk, glob, mkstemp, mkdtemp, utime, touch, chown, lchown, username, groupname, strerror, environ, euid, egid, groups, uname, readable, writable, executable, isabs, splitext, normpath, relpath, expanduser, samefile, mkfifo, sync, cpus, loadavg, urandom, isatty, sep, linesep, devnull, name, terminalsize and diskusage
