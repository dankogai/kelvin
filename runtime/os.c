/* os.c - OS and SYS (#94): the system around the program, and the
   program itself, as the prelude's namespaces: no import. Each call is
   C's, with errno given back where C sets it, 0 where it does not. */
#define _XOPEN_SOURCE 700 /* getcwd, setenv, stat, mkdir, opendir, getpid: POSIX, which -std=c11 hides on glibc */
#include "kelvin_prelude.h"

#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

/* ---------- SYS: the program ---------- */

static int sys_argc;
static char **sys_argv;

void kv_sys_init(int argc, char **argv) {
    sys_argc = argc;
    sys_argv = argv;
}

int kv_sys_argc_n(void) { return sys_argc; }
char **kv_sys_argv_p(void) { return sys_argv; }

const uint8_t *kv_sys_platform(void) {
#if defined(__APPLE__)
    return (const uint8_t *)"macos";
#elif defined(__linux__)
    return (const uint8_t *)"linux";
#elif defined(__FreeBSD__)
    return (const uint8_t *)"freebsd";
#elif defined(__OpenBSD__)
    return (const uint8_t *)"openbsd";
#elif defined(__NetBSD__)
    return (const uint8_t *)"netbsd";
#elif defined(_WIN32)
    return (const uint8_t *)"windows";
#else
    return (const uint8_t *)"unknown";
#endif
}

void kv_sys_exit(int code) {
    fflush(NULL);
    exit(code);
}

/* ---------- OS: the system around it ---------- */

static int err_or(int fallback) { return errno ? errno : fallback; }

int kv_os_cwd(kv_string *out) {
    size_t cap = 256;
    for (;;) {
        char *buf = malloc(cap);
        if (!buf)
            return ENOMEM;
        if (getcwd(buf, cap)) {
            *out = kv_string_text(buf);
            free(buf);
            return 0;
        }
        int e = err_or(EIO);
        free(buf);
        if (e != ERANGE)
            return e;
        cap *= 2;
    }
}

int kv_os_chdir(const void *path) { return chdir((const char *)path) == 0 ? 0 : err_or(EIO); }

const uint8_t *kv_os_env(const void *name) { return (const uint8_t *)getenv((const char *)name); }

int kv_os_setenv(const void *name, const void *value) {
    return setenv((const char *)name, (const char *)value, 1) == 0 ? 0 : err_or(EINVAL);
}

int kv_os_unsetenv(const void *name) { return unsetenv((const char *)name) == 0 ? 0 : err_or(EINVAL); }

bool kv_os_exists(const void *path) { return access((const char *)path, F_OK) == 0; }

static bool is_mode(const void *path, unsigned mask) {
    struct stat st;
    return stat((const char *)path, &st) == 0 && (st.st_mode & S_IFMT) == mask;
}

bool kv_os_isdir(const void *path) { return is_mode(path, S_IFDIR); }
bool kv_os_isfile(const void *path) { return is_mode(path, S_IFREG); }

int kv_os_remove(const void *path) { return remove((const char *)path) == 0 ? 0 : err_or(EIO); }

int kv_os_rename(const void *from, const void *to) {
    return rename((const char *)from, (const char *)to) == 0 ? 0 : err_or(EIO);
}

int kv_os_mkdir(const void *path) { return mkdir((const char *)path, 0777) == 0 ? 0 : err_or(EIO); }
int kv_os_rmdir(const void *path) { return rmdir((const char *)path) == 0 ? 0 : err_or(EIO); }

static int by_bytes(const void *a, const void *b) {
    const kv_string *x = a, *y = b;
    size_t n = x->b.count < y->b.count ? x->b.count : y->b.count;
    int c = n ? memcmp(x->b.at, y->b.at, n) : 0;
    return c ? c : x->b.count < y->b.count ? -1 : x->b.count > y->b.count;
}

/* the names in a directory, but . and .., sorted by their bytes, as
   Strings in an array to be taken over (#94); a name that is not UTF-8
   ends the program, as a String made of it would */
int kv_os_listdir(const void *path, kv_string **out, size_t *count) {
    DIR *d = opendir((const char *)path);
    if (!d)
        return err_or(EIO);
    kv_string *names = NULL;
    size_t n = 0, cap = 0;
    struct dirent *e;
    errno = 0;
    while ((e = readdir(d))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))
            continue;
        if (n == cap) {
            cap = cap ? cap * 2 : 16;
            kv_string *more = realloc(names, cap * sizeof *names);
            if (!more) {
                for (size_t i = 0; i < n; i++)
                    kv_string_free(&names[i]);
                free(names);
                closedir(d);
                return ENOMEM;
            }
            names = more;
        }
        names[n++] = kv_string_text(e->d_name);
        errno = 0;
    }
    int err = errno;
    closedir(d);
    if (err) {
        for (size_t i = 0; i < n; i++)
            kv_string_free(&names[i]);
        free(names);
        return err;
    }
    if (n > 1)
        qsort(names, n, sizeof *names, by_bytes);
    *out = names;
    *count = n;
    return 0;
}

/* a shell command's exit code, or -1 where it did not exit */
int kv_os_system(const void *command) {
    fflush(NULL);
    int st = system((const char *)command);
    return st != -1 && WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}

int kv_os_pid(void) { return (int)getpid(); }

/* ---------- more of OS (#95) ---------- */
#include <pwd.h>
#include <signal.h>
#include <time.h>

static void fill_stat(const struct stat *st, kv_stat *out) {
    out->dev = (long long)st->st_dev;
    out->ino = (long long)st->st_ino;
    out->mode = (int)st->st_mode;
    out->nlink = (long long)st->st_nlink;
    out->uid = (int)st->st_uid;
    out->gid = (int)st->st_gid;
    out->size = (long long)st->st_size;
    out->atime = (double)st->st_atime;
    out->mtime = (double)st->st_mtime;
    out->ctime = (double)st->st_ctime;
    out->isdir = S_ISDIR(st->st_mode);
    out->isfile = S_ISREG(st->st_mode);
    out->islink = S_ISLNK(st->st_mode);
}

int kv_os_stat(const void *path, kv_stat *out) {
    struct stat st;
    if (stat((const char *)path, &st) != 0)
        return err_or(EIO);
    fill_stat(&st, out);
    return 0;
}

int kv_os_lstat(const void *path, kv_stat *out) {
    struct stat st;
    if (lstat((const char *)path, &st) != 0)
        return err_or(EIO);
    fill_stat(&st, out);
    return 0;
}

bool kv_os_islink(const void *path) {
    struct stat st;
    return lstat((const char *)path, &st) == 0 && S_ISLNK(st.st_mode);
}

int kv_os_symlink(const void *target, const void *path) {
    return symlink((const char *)target, (const char *)path) == 0 ? 0 : err_or(EIO);
}

int kv_os_readlink(const void *path, kv_string *out) {
    char buf[4096];
    ssize_t n = readlink((const char *)path, buf, sizeof buf - 1);
    if (n < 0)
        return err_or(EIO);
    *out = kv_string_from_bytes(&(kv_bytes){(uint8_t *)buf, (size_t)n, 0});
    return 0;
}

int kv_os_link(const void *from, const void *to) { return link((const char *)from, (const char *)to) == 0 ? 0 : err_or(EIO); }
int kv_os_unlink(const void *path) { return unlink((const char *)path) == 0 ? 0 : err_or(EIO); }
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

int kv_os_ppid(void) { return (int)getppid(); }
int kv_os_uid(void) { return (int)getuid(); }
int kv_os_gid(void) { return (int)getgid(); }

const uint8_t *kv_os_user(void) {
    struct passwd *pw = getpwuid(getuid());
    return pw ? (const uint8_t *)pw->pw_name : NULL;
}

int kv_os_host(kv_string *out) {
    char buf[256];
    if (gethostname(buf, sizeof buf) != 0)
        return err_or(EIO);
    buf[sizeof buf - 1] = '\0';
    *out = kv_string_text(buf);
    return 0;
}

int kv_os_umask(int mask) { return (int)umask((mode_t)mask); }
int kv_os_kill(int pid, int sig) { return kill((pid_t)pid, sig) == 0 ? 0 : err_or(EIO); }

double kv_os_time(void) {
    struct timespec ts;
    if (!timespec_get(&ts, TIME_UTC))
        return (double)time(NULL);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

void kv_os_sleep(double seconds) {
    if (seconds <= 0)
        return;
    struct timespec ts = {(time_t)seconds, (long)((seconds - (double)(time_t)seconds) * 1e9)};
    while (nanosleep(&ts, &ts) != 0 && errno == EINTR)
        ;
}

const uint8_t *kv_os_tmpdir(void) {
    const char *t = getenv("TMPDIR");
    return (const uint8_t *)(t && *t ? t : "/tmp");
}

/* the last part of a path after its last /, and what is before it, as
   Python's os.path has them: basename("a/b/") is "", dirname("a") is "" */
kv_string kv_os_basename(const void *path) {
    const char *p = (const char *)path, *slash = strrchr(p, '/');
    return kv_string_text(slash ? slash + 1 : p);
}

kv_string kv_os_dirname(const void *path) {
    const char *p = (const char *)path, *slash = strrchr(p, '/');
    if (!slash)
        return kv_string_new();
    size_t n = (size_t)(slash - p);
    while (n > 1 && p[n - 1] == '/')
        n--;
    if (n == 0)
        n = 1; /* "/a": the root */
    return kv_string_from_bytes(&(kv_bytes){(uint8_t *)p, n, 0});
}

kv_string kv_os_join(const void *a, const void *b) {
    const char *x = (const char *)a, *y = (const char *)b;
    if (y[0] == '/' || !x[0])
        return kv_string_text(y);
    kv_string s = kv_string_text(x);
    if (x[strlen(x) - 1] != '/')
        kv_string_append_text(&s, "/");
    kv_string_append_text(&s, y);
    return s;
}

int kv_os_realpath(const void *path, kv_string *out) {
    char *r = realpath((const char *)path, NULL);
    if (!r)
        return err_or(EIO);
    *out = kv_string_text(r);
    free(r);
    return 0;
}
