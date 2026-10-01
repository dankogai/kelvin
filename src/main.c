/* main.c - the kelvinc driver */
/* expose mkdtemp, fork, waitpid and realpath under -std=c11 (realpath
   is an X/Open function, so glibc needs _XOPEN_SOURCE) */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#else
#define _XOPEN_SOURCE 700
#endif
#include "kelvin.h"

#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define KELVIN_VERSION "0.0.1"

static void usage(FILE *f) {
    fprintf(f,
            "usage: kelvinc [options] <file.k> [-- program args]\n"
            "\n"
            "options:\n"
            "  -o <path>   output path (default: source name without .k)\n"
            "  --emit-c    write the generated C (to -o, or stdout) and stop\n"
            "  --run       build, then run the program with the args after --\n"
            "  -O          optimize (-O2)\n"
            "  -g          include debug info\n"
            "  -v          print the C compiler command\n"
            "  --no-line   omit #line directives from the generated C\n"
            "  --version   print the version\n"
            "\n"
            "environment:\n"
            "  CC            C compiler to use (default: cc)\n"
            "  KELVIN_CFLAGS extra flags for the C compiler, space-separated\n"
            "  KELVIN_HOME   where to find kelvin_prelude.h and libkelvin.a\n");
}

static char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f)
        fatal("cannot open '%s'", path);
    Buf b = {0};
    buf_puts(&b, "");
    char chunk[65536];
    size_t n;
    while ((n = fread(chunk, 1, sizeof chunk, f)) > 0)
        buf_putn(&b, chunk, n);
    fclose(f);
    if (strlen(b.buf) != b.len)
        fatal("'%s' contains a NUL byte", path);
    return b.buf;
}

static void write_file(const char *path, const char *text) {
    FILE *f = fopen(path, "wb");
    if (!f)
        fatal("cannot write '%s'", path);
    fputs(text, f);
    if (fclose(f) != 0)
        fatal("cannot write '%s'", path);
}

static int run(char **argv, bool verbose) {
    if (verbose) {
        for (int i = 0; argv[i]; i++)
            fprintf(stderr, "%s%s", i ? " " : "", argv[i]);
        fprintf(stderr, "\n");
    }
    fflush(stdout);
    pid_t pid = fork();
    if (pid < 0)
        fatal("fork failed");
    if (pid == 0) {
        execvp(argv[0], argv);
        fprintf(stderr, "kelvinc: cannot run '%s'\n", argv[0]);
        _exit(127);
    }
    int status;
    if (waitpid(pid, &status, 0) < 0)
        fatal("waitpid failed");
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    return 128 + WTERMSIG(status);
}

/* The directory that holds the running kelvinc, or NULL. */
static char *exe_dir(const char *argv0) {
    char *path = NULL;
    if (strchr(argv0, '/')) {
        path = realpath(argv0, NULL);
    } else {
        const char *env = getenv("PATH");
        char *dirs = xstrdup(env ? env : "");
        for (char *d = strtok(dirs, ":"); d && !path; d = strtok(NULL, ":")) {
            char *candidate = strfmt("%s/%s", *d ? d : ".", argv0);
            if (access(candidate, X_OK) == 0)
                path = realpath(candidate, NULL);
        }
    }
    if (!path)
        return NULL;
    *strrchr(path, '/') = '\0';
    return path;
}

static bool file_exists(const char *path) { return access(path, R_OK) == 0; }

/* Find the prelude header and libkelvin.a under `home`, laid out either
   as the source tree (runtime/, libkelvin.a) or as an installation
   (include/, lib/). */
static bool runtime_in(const char *home, char **inc, char **lib) {
    if (!home)
        return false;
    const char *layouts[][2] = {{"runtime", "."}, {"include", "lib"}};
    for (int i = 0; i < 2; i++) {
        char *h = strfmt("%s/%s", home, layouts[i][0]);
        char *l = strfmt("%s/%s/libkelvin.a", home, layouts[i][1]);
        if (file_exists(strfmt("%s/kelvin_prelude.h", h)) && file_exists(l)) {
            *inc = h;
            *lib = l;
            return true;
        }
    }
    return false;
}

/* The runtime is looked for in $KELVIN_HOME, next to kelvinc (a build in
   the source tree), and in kelvinc's parent directory (an installation). */
static void find_runtime(const char *argv0, char **inc, char **lib) {
    char *dir = exe_dir(argv0);
    if (runtime_in(getenv("KELVIN_HOME"), inc, lib) || runtime_in(dir, inc, lib) ||
        (dir && runtime_in(strfmt("%s/..", dir), inc, lib)))
        return;
    fatal("cannot find the Kelvin runtime (kelvin_prelude.h and libkelvin.a); run 'make', or set KELVIN_HOME");
}

static char *default_output(const char *src) {
    const char *base = strrchr(src, '/');
    base = base ? base + 1 : src;
    size_t n = strlen(base);
    if (n > 2 && !strcmp(base + n - 2, ".k"))
        n -= 2;
    return xstrndup(base, n);
}

int main(int argc, char **argv) {
    const char *src_path = NULL, *out_path = NULL;
    bool emit_c = false, run_after = false, optimize = false, debug = false, verbose = false;
    bool line_directives = true;
    int prog_argc = 0;
    char **prog_argv = NULL;

    for (int i = 1; i < argc; i++) {
        char *a = argv[i];
        if (!strcmp(a, "--")) {
            prog_argv = argv + i + 1;
            prog_argc = argc - i - 1;
            break;
        } else if (!strcmp(a, "-o")) {
            if (++i >= argc)
                fatal("-o needs a path");
            out_path = argv[i];
        } else if (!strcmp(a, "--emit-c")) {
            emit_c = true;
        } else if (!strcmp(a, "--run")) {
            run_after = true;
        } else if (!strcmp(a, "-O")) {
            optimize = true;
        } else if (!strcmp(a, "-g")) {
            debug = true;
        } else if (!strcmp(a, "-v")) {
            verbose = true;
        } else if (!strcmp(a, "--no-line")) {
            line_directives = false;
        } else if (!strcmp(a, "--version")) {
            printf("kelvinc %s\n", KELVIN_VERSION);
            return 0;
        } else if (!strcmp(a, "-h") || !strcmp(a, "--help")) {
            usage(stdout);
            return 0;
        } else if (a[0] == '-') {
            usage(stderr);
            fatal("unknown option '%s'", a);
        } else if (src_path) {
            fatal("only one source file is supported for now");
        } else {
            src_path = a;
        }
    }
    if (!src_path) {
        usage(stderr);
        return 2;
    }

    char *src = read_file(src_path);
    set_source(src_path, src);
    int ntoks;
    Token *toks = lex(src_path, src, &ntoks);
    Program *prog = parse(toks, ntoks);
    char *c_code = gen_program(prog, line_directives);

    if (emit_c) {
        if (out_path)
            write_file(out_path, c_code);
        else
            fputs(c_code, stdout);
        return 0;
    }

    const char *tmpdir = getenv("TMPDIR");
    char *dir = strfmt("%s/kelvinc-XXXXXX", tmpdir && *tmpdir ? tmpdir : "/tmp");
    if (!mkdtemp(dir))
        fatal("cannot create a temporary directory");
    char *c_path = strfmt("%s/program.c", dir);
    write_file(c_path, c_code);

    char *rt_inc, *rt_lib;
    find_runtime(argv[0], &rt_inc, &rt_lib);
    char *exe = out_path ? xstrdup(out_path) : run_after ? strfmt("%s/program", dir) : default_output(src_path);
    const char *cc = getenv("CC");
    const char *base_args[] = {
        cc && *cc ? cc : "cc",
        "-std=c11",
        optimize ? "-O2" : "-O0",
        debug ? "-g" : "-g0",
        /* Kelvin's u8 is C's unsigned char, while string literals and libc
           use plain char. They are ABI-identical, so silence C's
           complaints about the mix. */
        "-Wno-unknown-warning-option",
        "-Wno-pointer-sign",
        "-Wno-incompatible-library-redeclaration",
        "-Wno-builtin-declaration-mismatch",
        /* gcc on x86-64 notes that passing a struct with a flexible array
           member changed ABI in GCC 4.4, e.g. for a derived toString */
        "-Wno-psabi",
    };
    List cc_args = {0};
    for (size_t i = 0; i < sizeof base_args / sizeof base_args[0]; i++)
        list_push(&cc_args, (void *)base_args[i]);
    /* #import "x.h" as C looks next to the .k file, as #include would */
    const char *slash = strrchr(src_path, '/');
    list_push(&cc_args, !slash ? "-I." : slash == src_path ? "-I/" : strfmt("-I%.*s", (int)(slash - src_path), src_path));
    /* the prelude header is a system header: its macros raise no warnings */
    list_push(&cc_args, "-isystem");
    list_push(&cc_args, rt_inc);
    /* extra flags, split on whitespace (e.g. -fsanitize=undefined) */
    const char *extra = getenv("KELVIN_CFLAGS");
    char *flags = xstrdup(extra ? extra : "");
    for (char *tok = strtok(flags, " \t\n"); tok; tok = strtok(NULL, " \t\n"))
        list_push(&cc_args, tok);
    const char *tail_args[] = {"-o", exe, c_path, rt_lib, "-lm", NULL};
    for (size_t i = 0; i < sizeof tail_args / sizeof tail_args[0]; i++)
        list_push(&cc_args, (void *)tail_args[i]);
    char **cc_argv = (char **)cc_args.data;
    int rc = run(cc_argv, verbose);
    unlink(c_path);
    if (rc != 0) {
        rmdir(dir);
        return rc;
    }

    if (!run_after) {
        rmdir(dir);
        return 0;
    }
    char **pargv = xcalloc((size_t)prog_argc + 2, sizeof(char *));
    pargv[0] = exe;
    for (int i = 0; i < prog_argc; i++)
        pargv[i + 1] = prog_argv[i];
    rc = run(pargv, false);
    if (!out_path)
        unlink(exe);
    rmdir(dir);
    return rc;
}
