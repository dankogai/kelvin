/* os.c - OS (#94): the system around the program, a module (#145); SYS,
   the program itself, is the prelude's, in runtime/sys.c (#302). Each call is
   C's, with errno given back where C sets it, 0 where it does not. A
   group at a time moves to runtime/os.k, written in Kelvin (#301): the
   working directory, the environment, files by path, the process ids;
   stat and the existence checks (#303); directories, walk and glob
   (#304); users and groups, and a file's owner (#305); paths (#306);
   processes and time (#309); temporary files (#310). */
/* POSIX and X/Open under -std=c11, which hides them: glibc wants
   _XOPEN_SOURCE, and macOS _DARWIN_C_SOURCE for mkdtemp and its kin,
   as kelvinc's own main.c has it; the BSDs show POSIX, X/Open and their
   own extensions where no macro asks, and hide their own, as
   sysconf(_SC_NPROCESSORS_ONLN) and getloadavg, where _XOPEN_SOURCE asks (#192) */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#elif !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)
#define _XOPEN_SOURCE 700
#define _DEFAULT_SOURCE 1 /* getloadavg (#102), a BSD extension glibc keeps for this */
#endif
#include "kelvin_prelude.h"
#include "kOS.h"
#include "kIO.h" /* the IO that OS.mkstemp fills */

#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

/* ---------- OS: the system around it ---------- */

static int err_or(int fallback) { return errno ? errno : fallback; }

/* ---------- more of OS (#95) ---------- */
#include <fcntl.h>
#include <glob.h>
#include <grp.h>
#include <sys/ioctl.h>
#include <sys/statvfs.h>
#include <sys/utsname.h>
#include <pwd.h>
#include <signal.h>
#include <time.h>

int kv_os_chmod(const void *path, int mode) { return chmod((const char *)path, (mode_t)mode) == 0 ? 0 : err_or(EIO); }

int kv_os_truncate(const void *path, long long size) {
    return truncate((const char *)path, (off_t)size) == 0 ? 0 : err_or(EIO);
}

/* mkdir -p: each directory on the way, those there already left alone */
int kv_os_makedirs(const void *path) {
    const char *p = (const char *)path;
    size_t n = strlen(p);
    char *copy = malloc(n + 1);
    if (!copy)
        return ENOMEM;
    memcpy(copy, p, n + 1);
    for (size_t i = 1; i <= n; i++) {
        if (copy[i] != '/' && copy[i] != '\0')
            continue;
        char c = copy[i];
        copy[i] = '\0';
        if (mkdir(copy, 0777) != 0 && errno != EEXIST) {
            int e = err_or(EIO);
            free(copy);
            return e;
        }
        copy[i] = c;
    }
    struct stat st;
    bool dir = stat(p, &st) == 0 && S_ISDIR(st.st_mode);
    free(copy);
    return dir ? 0 : ENOTDIR;
}

int kv_os_host(kv_string *out) {
    char buf[256];
    if (gethostname(buf, sizeof buf) != 0)
        return err_or(EIO);
    buf[sizeof buf - 1] = '\0';
    *out = kv_string_text(buf);
    return 0;
}

/* ---------- walking and globbing (#96) ---------- */

static int push_string(kv_string **out, size_t *n, size_t *cap, kv_string s) {
    if (*n == *cap) {
        size_t more = *cap ? *cap * 2 : 16;
        kv_string *grown = realloc(*out, more * sizeof *grown);
        if (!grown) {
            kv_string_free(&s);
            return ENOMEM;
        }
        *out = grown;
        *cap = more;
    }
    (*out)[(*n)++] = s;
    return 0;
}

static void free_strings(kv_string *at, size_t n) {
    for (size_t i = 0; i < n; i++)
        kv_string_free(&at[i]);
    free(at);
}

/* ---------- temporary files (#97) ---------- */

/* ---------- a file's times (#98) ---------- */

/* ---------- what Python's os has beyond these (#102) ---------- */

extern char **environ;

kv_string kv_os_strerror(int code) { return kv_string_text(strerror(code)); }

/* every "NAME=value" of the environment, in C's order */
int kv_os_environ(kv_string **out, size_t *count) {
    kv_string *at = NULL;
    size_t n = 0, cap = 0;
    for (size_t i = 0; environ && environ[i]; i++) {
        int e = push_string(&at, &n, &cap, kv_string_text(environ[i]));
        if (e) {
            free_strings(at, n);
            return e;
        }
    }
    *out = at;
    *count = n;
    return 0;
}

int kv_os_uname(kv_uname *out) {
    struct utsname u;
    if (uname(&u) < 0)
        return err_or(EIO);
    out->sysname = kv_string_text(u.sysname);
    out->nodename = kv_string_text(u.nodename);
    out->release = kv_string_text(u.release);
    out->version = kv_string_text(u.version);
    out->machine = kv_string_text(u.machine);
    return 0;
}

bool kv_os_readable(const void *path) { return access((const char *)path, R_OK) == 0; }
bool kv_os_writable(const void *path) { return access((const char *)path, W_OK) == 0; }
bool kv_os_executable(const void *path) { return access((const char *)path, X_OK) == 0; }

bool kv_os_samefile(const void *a, const void *b) {
    struct stat x, y;
    return stat((const char *)a, &x) == 0 && stat((const char *)b, &y) == 0 && x.st_dev == y.st_dev && x.st_ino == y.st_ino;
}

int kv_os_mkfifo(const void *path) { return mkfifo((const char *)path, 0666) == 0 ? 0 : err_or(EIO); }
void kv_os_sync(void) { sync(); }

int kv_os_cpus(void) {
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 1;
}

int kv_os_loadavg(kv_loadavg *out) {
    double v[3];
    if (getloadavg(v, 3) != 3)
        return err_or(EIO);
    out->one = v[0];
    out->five = v[1];
    out->fifteen = v[2];
    return 0;
}

int kv_os_urandom(long long n, kv_bytes *out) {
    if (n < 0)
        return EINVAL;
    FILE *fp = fopen("/dev/urandom", "rb");
    if (!fp)
        return err_or(EIO);
    kv_bytes b = kv_bytes_zeros((size_t)n);
    size_t got = n ? fread(b.at, 1, (size_t)n, fp) : 0;
    fclose(fp);
    if (got != (size_t)n) {
        kv_bytes_free(&b);
        return EIO;
    }
    *out = b;
    return 0;
}

bool kv_os_isatty(int fd) { return isatty(fd) == 1; }
const uint8_t *kv_os_sep(void) { return (const uint8_t *)"/"; }
const uint8_t *kv_os_linesep(void) { return (const uint8_t *)"\n"; }
const uint8_t *kv_os_devnull(void) { return (const uint8_t *)"/dev/null"; }
const uint8_t *kv_os_name(void) { return (const uint8_t *)"posix"; }

/* the terminal on stdout, else ENOTTY */
int kv_os_terminalsize(kv_terminalsize *out) {
    struct winsize w;
    if (ioctl(1, TIOCGWINSZ, &w) != 0)
        return err_or(ENOTTY);
    out->columns = w.ws_col;
    out->lines = w.ws_row;
    return 0;
}

int kv_os_diskusage(const void *path, kv_diskusage *out) {
    struct statvfs v;
    if (statvfs((const char *)path, &v) != 0)
        return err_or(EIO);
    long long unit = (long long)v.f_frsize;
    out->total = (long long)v.f_blocks * unit;
    out->free = (long long)v.f_bavail * unit;
    out->used = ((long long)v.f_blocks - (long long)v.f_bfree) * unit;
    return 0;
}
