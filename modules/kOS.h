/* kOS.h - the declarations of libkOS, Kelvin's OS and SYS (#94) as a
   module (#145): the system around the program, and the program itself.
   #import <OS> brings this header in through modules/OS.kh and links
   libkOS, built from runtime/os.c. */
#ifndef KELVIN_KOS_H
#define KELVIN_KOS_H

#include "kelvin_prelude.h"

struct kv_io; /* an IO, kIO.h's: OS.mkstemp fills one */
int kv_os_cwd(kv_string *out);
int kv_os_chdir(const void *path);
const uint8_t *kv_os_env(const void *name);
int kv_os_setenv(const void *name, const void *value);
int kv_os_unsetenv(const void *name);
bool kv_os_exists(const void *path);
bool kv_os_isdir(const void *path);
bool kv_os_isfile(const void *path);
int kv_os_remove(const void *path);
int kv_os_rename(const void *from, const void *to);
int kv_os_mkdir(const void *path);
int kv_os_rmdir(const void *path);
int kv_os_listdir(const void *path, kv_string **out, size_t *count);
int kv_os_system(const void *command);
int kv_os_pid(void);
/* OS.stat and OS.lstat (#95): what C's stat gives, as a struct kelvinc copies into its own */
typedef struct kv_stat {
    long long dev, ino;
    int mode;
    long long nlink;
    int uid, gid;
    long long size;
    double atime, mtime, ctime;
    bool isdir, isfile, islink;
} kv_stat;
int kv_os_stat(const void *path, kv_stat *out);
int kv_os_lstat(const void *path, kv_stat *out);
int kv_os_futime(int fd, double atime, double mtime);
int kv_os_ftouch(int fd);
bool kv_os_islink(const void *path);
int kv_os_symlink(const void *target, const void *path);
int kv_os_readlink(const void *path, kv_string *out);
int kv_os_link(const void *from, const void *to);
int kv_os_unlink(const void *path);
int kv_os_chmod(const void *path, int mode);
int kv_os_truncate(const void *path, long long size);
int kv_os_makedirs(const void *path);
int kv_os_ppid(void);
int kv_os_uid(void);
int kv_os_gid(void);
bool kv_os_user(kv_string *out);
int kv_os_host(kv_string *out);
int kv_os_umask(int mask);
int kv_os_kill(int pid, int sig);
double kv_os_time(void);
void kv_os_sleep(double seconds);
const uint8_t *kv_os_tmpdir(void);
kv_string kv_os_basename(const void *path);
kv_string kv_os_dirname(const void *path);
kv_string kv_os_join(const void *a, const void *b);
int kv_os_realpath(const void *path, kv_string *out);
int kv_os_walk(const void *path, kv_string **out, size_t *count);
int kv_os_glob(const void *pattern, kv_string **out, size_t *count);
int kv_os_mkstemp(const void *prefix, struct kv_io *io, kv_string *path); /* fills an IO (kIO.h) */
int kv_os_mkdtemp(const void *prefix, kv_string *out);
int kv_os_utime(const void *path, double atime, double mtime);
int kv_os_touch(const void *path);
/* more of Python's os (#102): what each gives, as structs kelvinc copies by name */
typedef struct kv_uname { kv_string sysname, nodename, release, version, machine; } kv_uname;
typedef struct kv_splitext { kv_string root, ext; } kv_splitext;
typedef struct kv_loadavg { double one, five, fifteen; } kv_loadavg;
typedef struct kv_terminalsize { long long columns, lines; } kv_terminalsize;
typedef struct kv_diskusage { long long total, used, free; } kv_diskusage;
kv_string kv_os_strerror(int code);
int kv_os_environ(kv_string **out, size_t *count);
int kv_os_euid(void);
int kv_os_egid(void);
int kv_os_groups(int32_t **out, size_t *count);
int kv_os_uname(kv_uname *out);
bool kv_os_readable(const void *path);
bool kv_os_writable(const void *path);
bool kv_os_executable(const void *path);
bool kv_os_isabs(const void *path);
int kv_os_splitext(const void *path, kv_splitext *out);
kv_string kv_os_normpath(const void *path);
kv_string kv_os_relpath(const void *path, const void *start);
kv_string kv_os_expanduser(const void *path);
bool kv_os_samefile(const void *a, const void *b);
int kv_os_mkfifo(const void *path);
void kv_os_sync(void);
int kv_os_cpus(void);
int kv_os_loadavg(kv_loadavg *out);
int kv_os_urandom(long long n, kv_bytes *out);
bool kv_os_isatty(int fd);
const uint8_t *kv_os_sep(void);
const uint8_t *kv_os_linesep(void);
const uint8_t *kv_os_devnull(void);
const uint8_t *kv_os_name(void);
int kv_os_terminalsize(kv_terminalsize *out);
int kv_os_diskusage(const void *path, kv_diskusage *out);
int kv_os_chown(const void *path, int uid, int gid);
int kv_os_lchown(const void *path, int uid, int gid);
bool kv_os_username(int uid, kv_string *out);
bool kv_os_groupname(int gid, kv_string *out);

#endif
