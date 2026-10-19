/* kIO.h - the declarations of libkIO, Kelvin's IO (#82) as a module (#144):
   stdio as an owner. #import <IO> brings this header in through
   modules/IO.kh and links libkIO, which is built from runtime/io.c and
   calls libkOS, so IO.kh imports <OS> too. */
#ifndef KELVIN_KIO_H
#define KELVIN_KIO_H

#include "kelvin_prelude.h"
#include "kOS.h"

/* fp is a FILE *, closed when its block ends if the IO opened it, flushed
   if it is stdin, stdout or stderr; opening and reading whole give errno.
   A void *, so that this header needs no <stdio.h>, whose names a program
   may declare itself */
typedef struct kv_io {
    void *fp;
    int kind;   /* 0 a stream never closed, 1 a file (fclose), 3 a process by its pid (#87, #90, #100) */
    int status; /* a process's exit code once closed, else -1 */
    int signal; /* the signal that ended a process, once closed, 0 when none, else -1 (#89) */
    long pid;   /* a process run without the shell (#90), waited for when closed */
    char *path; /* the path it was opened with (#101), freed with it; NULL for a stream or a process */
    int error;  /* the errno of an open that failed (#109), 0 otherwise; such an IO is as a closed one */
    char *named; /* the last name kv_io_abspath found (#195), freed with it; NULL before one */
} kv_io;
kv_io kv_io_open(const void *path, const void *mode); /* the IO straight (#109), .error set when it did not open */
kv_io kv_io_fdopen(int fd, const void *mode);
int kv_io_error(kv_io *f);
/* a process's IO and a pipe's two ends, straight (#110): .error the errno when it could not start */
kv_io kv_io_popen(const void *command, const void *mode);
void kv_io_pipe(kv_io *reader, kv_io *writer);
kv_io kv_io_exec(const char *const *argv, const void *mode, const void *dir, const char *const *env, bool fresh);
kv_io kv_io_exec_cstrs(const uint8_t *const *at, size_t n, const void *mode, const void *dir, const char *const *env,
                       bool fresh);
kv_io kv_io_exec_strings(const kv_string *at, size_t n, const void *mode, const void *dir, const char *const *env,
                         bool fresh);
const char **kv_io_vector_cstrs(const uint8_t *const *at, size_t n);
const char **kv_io_vector_strings(const kv_string *at, size_t n);
void kv_io_vector_free(const char *const *v);
/* its path, and the OS's work on it (#101) */
const uint8_t *kv_io_path(kv_io *f);
kv_string kv_io_abspath(kv_io *f); /* of the path, else of the descriptor, else the last found; "" before one (#104, #105, #195) */
/* Arrays straight, none where the IO is no readable directory (#106) */
void kv_io_listdir(kv_io *f, kv_string **out, size_t *count);
void kv_io_walk(kv_io *f, kv_string **out, size_t *count);
void kv_io_glob(kv_io *f, const void *pattern, kv_string **out, size_t *count);
kv_stat kv_io_stat(kv_io *f);  /* of the open file itself: a Stat, no Result (#104) */
kv_stat kv_io_lstat(kv_io *f); /* the path's own, else the open file's */
bool kv_io_isdir(kv_io *f);
bool kv_io_isfile(kv_io *f);
bool kv_io_islink(kv_io *f);
bool kv_io_exists(kv_io *f);
/* the operations, each true when done (#108) */
bool kv_io_chmod(kv_io *f, int mode);
bool kv_io_chown(kv_io *f, int uid, int gid);
bool kv_io_truncate(kv_io *f, long long size);
bool kv_io_remove(kv_io *f);
bool kv_io_rename(kv_io *f, const void *to);
bool kv_io_utime(kv_io *f, double atime, double mtime);
bool kv_io_touch(kv_io *f);
kv_string kv_io_basename(kv_io *f);
kv_string kv_io_dirname(kv_io *f);
kv_string kv_io_join(kv_io *f, const void *name);
int kv_io_status(kv_io *f);
int kv_io_signal(kv_io *f);
bool kv_io_kill(kv_io *f, int sig);
int kv_io_pid(kv_io *f);
int kv_io_fd(kv_io *f);
kv_io *kv_io_std(int which);
void kv_io_free(kv_io *f);
kv_io kv_io_take(kv_io *f);
kv_io kv_io_copy(const kv_io *f);
void kv_io_discard(kv_io v);
void kv_io_close(kv_io *f);
void kv_io_flush(kv_io *f);
kv_bytes kv_io_read_all(kv_io *f);     /* the rest of the file, straight (#107) */
kv_string kv_io_read_string(kv_io *f); /* the same as UTF-8, or the program ends */
bool kv_io_read_chunk(kv_io *f, size_t n, kv_bytes *buf);
bool kv_io_read_line(kv_io *f, kv_string *line);
void kv_io_write_text(kv_io *f, const void *s);
void kv_io_write_bytes(kv_io *f, const kv_bytes *b);
void kv_io_write_string(kv_io *f, const kv_string *s);
void kv_io_write_owned_bytes(kv_io *f, kv_bytes b);
void kv_io_write_owned_string(kv_io *f, kv_string s);
void *kv_io_fp(kv_io *f);
bool kv_io_eof(kv_io *f);
bool kv_io_isatty(kv_io *f);
long long kv_io_position(kv_io *f);
long long kv_io_count(kv_io *f);
bool kv_io_seek(kv_io *f, long long offset);
void kv_io_rewind(kv_io *f);
bool kv_io_read_byte(kv_io *f, uint8_t *out);

#endif
