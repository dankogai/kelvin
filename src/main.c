/* main.c - the kelvinc driver */
/* expose mkdtemp, fork, waitpid and realpath under -std=c11 (realpath
   is an X/Open function, so glibc needs _XOPEN_SOURCE; the BSDs show it
   all where no macro asks, and less where one asks, #192) */
#if defined(__APPLE__)
#define _DARWIN_C_SOURCE
#elif !defined(__FreeBSD__) && !defined(__NetBSD__) && !defined(__OpenBSD__) && !defined(__DragonFly__)
#define _XOPEN_SOURCE 700
#endif
#include "kelvin.h"

#include <dirent.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#define KELVIN_VERSION "0.2.0"

static void usage(FILE *f) {
    fprintf(f,
            "usage: kelvinc [options] <file.k> [file.o ...] [-- program args]\n"
            "       kelvinc [options] -o <program> file.o ...\n"
            "\n"
            "options:\n"
            "  -o <path>   output path (default: source name without .k)\n"
            "  -c          compile the file into an object, file.o or the -o path, and stop\n"
            "              (#281); .o and .a files are linked with the source, or alone\n"
            "  --emit-c    write the generated C (to -o, or stdout) and stop\n"
            "  --runtime   compile a file of kelvinc's runtime, runtime/*.k, into an object,\n"
            "              as -c, its kv_ functions by the names kelvin_prelude.h declares (#289)\n"
            "  --run       build, then run the program with the args after --\n"
            "  -O          optimize (-O2)\n"
            "  -g          include debug info\n"
            "  -v          print the C compiler command\n"
            "  --no-line   omit #line directives from the generated C\n"
            "  --lib       build the file into a module (#146): M.kh, its declarations, and\n"
            "              libkM.a, with libkM.dylib or .so for C (#147), in ./modules or\n"
            "              the directory given by -o; .o and .a files after the source go\n"
            "              into the library too (#156)\n"
            "  --prelude   build a module of the prelude (#504): M.kh and its object, M.o, in\n"
            "              the directory given by -o, for libkelvin to hold; no libkM\n"
            "  --version   print the version\n"
            "\n"
            "environment:\n"
            "  CC            C compiler to use (default: cc)\n"
            "  KELVIN_CFLAGS extra flags for the C compiler, space-separated\n"
            "  KELVIN_HOME   where to find modules/ (kelvin_prelude.h, libkelvin.a and the\n"
            "                Kelvin files of #import <x.k>), after ./modules for <x.k>\n");
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

/* A Kelvin file to import is a readable file, not a directory (#40) */
static bool kelvin_file(const char *path) {
    struct stat st;
    return file_exists(path) && stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

static bool is_dir(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

/* Kelvin's own modules/ (#46), which holds kelvin_prelude.h, libkelvin
   and the Kelvin files of #import <x.k>: the first of $KELVIN_HOME,
   kelvinc's directory (a build in the source tree) and its parent (an
   installation) with modules/kelvin_prelude.h, or with
   lib/kelvin/modules/kelvin_prelude.h as make install lays it out; or
   NULL */
static char *kelvin_modules(const char *argv0) {
    static char *found;
    static bool looked;
    if (looked)
        return found;
    looked = true;
    char *dir = exe_dir(argv0);
    const char *homes[] = {getenv("KELVIN_HOME"), dir, dir ? strfmt("%s/..", dir) : NULL};
    for (int i = 0; i < 3 && !found; i++)
        for (int j = 0; j < 2 && homes[i] && !found; j++) {
            char *m = strfmt("%s/%s", homes[i], j ? "lib/kelvin/modules" : "modules");
            if (file_exists(strfmt("%s/kelvin_prelude.h", m)))
                found = m;
        }
    return found;
}

/* The runtime: the prelude header and libkelvin.a in Kelvin's modules/;
   an object, which links nothing, needs only the header (#289), so that
   the runtime's own .k files build before libkelvin.a is there */
static void find_runtime(const char *argv0, char **inc, char **lib, bool linking) {
    char *m = kelvin_modules(argv0);
    if (!m)
        fatal("cannot find Kelvin's modules/ (kelvin_prelude.h and libkelvin.a); set KELVIN_HOME");
    *inc = m;
    *lib = strfmt("%s/libkelvin.a", m);
    if (linking && !file_exists(*lib))
        fatal("cannot find libkelvin.a in %s; run 'make'", m);
}

/* ---------- #import of Kelvin files (#40) ---------- */

/* The Kelvin files already brought in, by their device and inode, so that
   another path to one, a hard link too, is the same file */
static List imported;

static bool imported_already(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0)
        return false;
    char *id = strfmt("%lld:%lld", (long long)st.st_dev, (long long)st.st_ino);
    for (int j = 0; j < imported.len; j++)
        if (!strcmp(imported.data[j], id))
            return true;
    list_push(&imported, id);
    return false;
}

/* whether path is among the files brought in already, without adding it */
static bool imported_has(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0)
        return false;
    char *id = strfmt("%lld:%lld", (long long)st.st_dev, (long long)st.st_ino);
    for (int j = 0; j < imported.len; j++)
        if (!strcmp(imported.data[j], id))
            return true;
    return false;
}

/* The file that #import <name> or "name" means: "name" next to the
   importing file, <name> in ./modules or else in Kelvin's modules/ (#46),
   as <math.k> is the source tree's modules/math.k */
/* The libraries of the modules imported as M.kh (#143), libkM.a beside the
   header, or -lkM where only a shared libkM is, in the order imported, so
   that one a later one calls comes after it; linked before libkelvin */
static List module_libs;

/* A module's library and what follows it there, its libkM.link's flags
   (#599): where they are in module_libs, and the modules its header
   imports, by their headers' paths. A library goes before those its
   module imports, as C's linker reads each once, in order: one imported
   already, by the program or by another module, is moved after the one
   whose header imports it now, and what it imports after it. BigNum's
   header imports Rational's, so #import <Rational> and then #import
   <BigNum> link libkBigNum.a before libkRational.a. */
typedef struct {
    const char *path;
    int start, len;
    List deps; /* char *: the headers its own imports */
    bool moving;
} ModuleLib;
static List module_marks;       /* ModuleLib * */
static const char *importing;   /* the file whose #imports with_imports reads, NULL of the program's own */

static ModuleLib *module_mark(const char *path) {
    for (int i = 0; path && i < module_marks.len; i++)
        if (!strcmp(((ModuleLib *)module_marks.data[i])->path, path))
            return module_marks.data[i];
    return NULL;
}

static void module_lib_after(ModuleLib *m) {
    if (!m || m->moving || !m->len)
        return;
    m->moving = true;
    void **held = xmalloc(sizeof(void *) * (size_t)m->len);
    memcpy(held, module_libs.data + m->start, sizeof(void *) * (size_t)m->len);
    memmove(module_libs.data + m->start, module_libs.data + m->start + m->len,
            sizeof(void *) * (size_t)(module_libs.len - m->start - m->len));
    memcpy(module_libs.data + module_libs.len - m->len, held, sizeof(void *) * (size_t)m->len);
    free(held);
    for (int i = 0; i < module_marks.len; i++) {
        ModuleLib *o = module_marks.data[i];
        if (o != m && o->start > m->start)
            o->start -= m->len;
    }
    m->start = module_libs.len - m->len;
    for (int i = 0; i < m->deps.len; i++)
        module_lib_after(module_mark(m->deps.data[i]));
    m->moving = false;
}

/* the flags of libkM.link beside a module's library (#482), split on
   whitespace, such as -L/opt/local/lib -lssl -lcrypto: what the library
   needs of the system, linked after it */
static void link_flags(const char *dir, const char *name, List *out) {
    FILE *f = fopen(strfmt("%s/libk%s.link", dir, name), "r");
    if (!f)
        return;
    char buf[4096];
    size_t n = fread(buf, 1, sizeof buf - 1, f);
    fclose(f);
    buf[n] = '\0';
    for (char *tok = strtok(buf, " \t\r\n"); tok; tok = strtok(NULL, " \t\r\n"))
        list_push(out, xstrdup(tok));
}

static void module_library_of(const char *path);

static void module_library(const char *path) {
    int start = module_libs.len;
    module_library_of(path);
    if (module_libs.len > start && !module_mark(path)) {
        ModuleLib *m = xcalloc(1, sizeof *m);
        m->path = xstrdup(path);
        m->start = start;
        m->len = module_libs.len - start;
        list_push(&module_marks, m);
    }
}

static void module_library_of(const char *path) {
    size_t n = strlen(path);
    if (n < 4 || strcmp(path + n - 3, ".kh"))
        return;
    const char *slash = strrchr(path, '/');
    char *dir = slash ? xstrndup(path, (size_t)(slash - path)) : xstrdup(".");
    char *name = xstrndup(slash ? slash + 1 : path, (slash ? strlen(slash + 1) : n) - 3);
    char *a = strfmt("%s/libk%s.a", dir, name);
    if (file_exists(a)) {
        list_push(&module_libs, a);
        link_flags(dir, name, &module_libs);
        return;
    }
    if (file_exists(strfmt("%s/libk%s.dylib", dir, name)) || file_exists(strfmt("%s/libk%s.so", dir, name))) {
        list_push(&module_libs, strfmt("-lk%s", name));
        link_flags(dir, name, &module_libs);
    }
}

static char *import_path(Token *t, const char *argv0) {
    char *name = xstrndup(t->text + 1, strlen(t->text) - 2);
    bool bare = !strchr(name, '.'); /* <JSON> is <JSON.k> (#112), after <JSON.kh>, a module's header (#143) */
    if (bare)
        name = strfmt("%s.k", name);
    if (t->text[0] == '"') {
        const char *slash = strrchr(t->pos.file, '/');
        char *path = slash && name[0] != '/' ? strfmt("%.*s/%s", (int)(slash - t->pos.file), t->pos.file, name)
                                             : name;
        if (!kelvin_file(path))
            error_at(t->pos, "cannot find %s next to the file that imports it", t->text);
        return path;
    }
    const char *dirs[] = {"./modules", kelvin_modules(argv0)};
    for (int i = 0; i < 2; i++) {
        if (bare && dirs[i] && kelvin_file(strfmt("%s/%sh", dirs[i], name)))
            return strfmt("%s/%sh", dirs[i], name);
        if (dirs[i] && kelvin_file(strfmt("%s/%s", dirs[i], name)))
            return strfmt("%s/%s", dirs[i], name);
    }
    if (!strcmp(t->text, "<BigFloat>")) /* renamed (#590) */
        error_at(t->pos, "<BigFloat> is <BigNum> now, with CBR, CBF and math's functions of them (#590): write "
                         "#import <BigNum>");
    error_at(t->pos, "cannot find %s (%s%s) in ./modules or in Kelvin's modules/ (KELVIN_HOME, or next to kelvinc)",
             t->text, bare ? strfmt("%sh or ", name) : "", name);
}

/* The tokens with each #import of a Kelvin file followed by that file's
   tokens, once per program, so that its declarations are compiled as if
   written there. The import stays, and a TK_FILE_END follows the file, so
   that the parser sees where each file begins and ends: a declaration
   there ends, an unfinished one is an error in its own file, and an
   import inside a body is an error at the import. A "header.h" that an
   imported file imports as C is looked for next to that file, as C's
   #include "..." does, so it is written with its full path. */
static Token *with_imports(Token *toks, int n, int *out_n, const char *argv0) {
    List out = {0};
    for (int i = 0; i < n; i++) {
        Token *t = xmalloc(sizeof *t);
        *t = toks[i];
        list_push(&out, t);
        if (t->imported && t->kind == TK_IMPORT && t->text[0] == '"' && t->text[1] != '/') {
            /* the importing file's directory, made absolute, and the name
               as written, so that a header that is a symlink keeps its own
               directory for its own #include "..." */
            const char *slash = strrchr(t->pos.file, '/');
            char *dir = realpath(slash ? strfmt("%.*s", (int)(slash - t->pos.file), t->pos.file) : ".", NULL);
            char *name = xstrndup(t->text + 1, strlen(t->text) - 2);
            char *path = dir ? strfmt("%s/%s", dir, name) : NULL;
            if (path && file_exists(path) && !strpbrk(path, "\"\n"))
                t->text = strfmt("\"%s\"", path);
        }
        if (toks[i].kind != TK_IMPORT_K)
            continue;
        char *path = import_path(&toks[i], argv0);
        ModuleLib *by = module_mark(importing);
        if (by) /* a module's header imports it (#599): its library after that module's */
            list_push(&by->deps, path);
        if (imported_already(path)) {
            if (by)
                module_lib_after(module_mark(path));
            continue;
        }
        module_library(path);
        char *src = read_file(path);
        set_source(path, src);
        int m, k;
        Token *more = lex(path, src, &m);
        for (int j = 0; j < m; j++)
            more[j].imported = true;
        Pos eof = more[m - 1].pos;
        const char *outer = importing;
        importing = path;
        more = with_imports(more, m - 1, &k, argv0); /* without its end of file */
        importing = outer;
        for (int j = 0; j < k; j++) {
            Token *u = xmalloc(sizeof *u);
            *u = more[j];
            list_push(&out, u);
        }
        Token *end = xmalloc(sizeof *end);
        *end = (Token){TK_FILE_END, eof, path, eof.line, false, true, false, false, false, false};
        list_push(&out, end);
    }
    Token *all = xmalloc(sizeof(Token) * (size_t)(out.len + 1));
    for (int i = 0; i < out.len; i++)
        all[i] = *(Token *)out.data[i];
    *out_n = out.len;
    return all;
}

/* ---------- the Kelvin namespace (#600) ---------- */

/* A file of the tokens: where its braces are, the files it imports, and
   the types of its own it sees that have the name of one of the prelude's:
   those it defines, struct BigInt { ... }, and those of the files it
   imports. Such a type hides the prelude's under the bare name there, and
   nowhere else: BigNum.kh's c64 is math's, whatever the program defines */
typedef struct {
    const char *path;
    char *id;      /* its device and inode, as imported_already's, or its path */
    bool prelude;  /* a file of the prelude, which defines none of them */
    int depth;
    char kinds[64]; /* what each brace it is in belongs to: 's' a struct's or a union's body, 'x' an extend's, 'o' any other */
    List imports;  /* char *: the ids of the files it imports */
    List sees;     /* char *: the names */
} SrcFile;
static List src_files; /* SrcFile * */

static char *file_id(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0)
        return xstrdup(path);
    return strfmt("%lld:%lld", (long long)st.st_dev, (long long)st.st_ino);
}

static SrcFile *src_file_of(const char *path) {
    static SrcFile *last;
    if (last && last->path == path)
        return last;
    for (int i = 0; i < src_files.len; i++) {
        SrcFile *f = src_files.data[i];
        if (f->path == path || !strcmp(f->path, path))
            return last = f;
    }
    SrcFile *f = xcalloc(1, sizeof *f);
    f->path = path;
    f->id = file_id(path);
    f->prelude = prelude_file(path);
    list_push(&src_files, f);
    return last = f;
}

static bool tok_is(const Token *t, TokKind kind, const char *text) { return t->kind == kind && !strcmp(t->text, text); }

/* is s one of the names of l? */
static bool name_in(List *l, const char *s) {
    for (int i = 0; i < l->len; i++)
        if (!strcmp(l->data[i], s))
            return true;
    return false;
}

/* does the token at i define a type, struct T { ... }, enum T { ... } or
   typealias T = ..., and not name one, p:struct tm^? Its name is the next */
static bool defines_type(const Token *toks, int n, int i) {
    if (i + 2 >= n || toks[i + 1].kind != TK_IDENT || (i > 0 && tok_is(&toks[i - 1], TK_PUNCT, ".")))
        return false;
    if (tok_is(&toks[i], TK_IDENT, "typealias"))
        return tok_is(&toks[i + 2], TK_PUNCT, "=");
    if (toks[i].kind != TK_KEYWORD ||
        (strcmp(toks[i].text, "struct") && strcmp(toks[i].text, "union") && strcmp(toks[i].text, "enum")))
        return false;
    return tok_is(&toks[i + 2], TK_PUNCT, "{") || tok_is(&toks[i + 2], TK_PUNCT, "<") || tok_is(&toks[i + 2], TK_PUNCT, ":");
}

/* The words of the enum at i, enum E { a, b = 2 }, as the places of their
   tokens: of an enum of words alone, which are names of the whole program;
   none of an enum with values, whose cases are the enum's own. *end is its
   closing brace */
static List enum_words(const Token *toks, int n, int i, int *end) {
    List words = {0};
    *end = i + 3;
    bool values = false;
    while (*end < n && !tok_is(&toks[*end], TK_PUNCT, "}")) {
        values = values || tok_is(&toks[*end], TK_PUNCT, ":") || tok_is(&toks[*end], TK_PUNCT, "{");
        (*end)++;
    }
    for (int k = i + 3; !values && k < *end; k++) {
        bool first = tok_is(&toks[k - 1], TK_PUNCT, "{") || tok_is(&toks[k - 1], TK_PUNCT, ",") ||
                     tok_is(&toks[k - 1], TK_PUNCT, ";") ||
                     (toks[k].pos.line > toks[k - 1].end_line && !tok_is(&toks[k - 1], TK_PUNCT, "="));
        if (toks[k].kind == TK_IDENT && first)
            list_push(&words, (void *)(intptr_t)k);
    }
    return words;
}

static bool enum_at(const Token *toks, int n, int i) {
    return i + 2 < n && tok_is(&toks[i], TK_KEYWORD, "enum") && toks[i + 1].kind == TK_IDENT &&
           tok_is(&toks[i + 2], TK_PUNCT, "{");
}

/* the tokens that declare a member, a struct's x: T or an extend's let x,
   which no name of the top level hides: it is read after a dot (#604) */
static bool *own_skip;
static int own_skip_n;

/* Each file's own names among the prelude's (#600, #604): its types', its
   functions' and the words of its enums. A file has one where it defines,
   at its top level, a type of the name, a variable of it, a word of an
   enum of its own, or, of a word of the prelude's, a function; a function
   of the name of one of the prelude's functions is an overload, and no
   such name (#600). It sees those and what the files it imports see, as
   it reads them too. A file of the prelude sees none */
static void own_types(Token *toks, int n, List *types, List *fns, List *words, const char *argv0) {
    for (int i = 0; i < src_files.len; i++) {
        SrcFile *f = src_files.data[i];
        f->depth = 0;
        f->imports.len = f->sees.len = 0;
    }
    own_skip = xcalloc((size_t)n + 1, sizeof *own_skip);
    own_skip_n = n;
    bool any = false;
    for (int i = 0; i < n; i++) {
        SrcFile *f = src_file_of(toks[i].pos.file);
        char in = f->depth > 0 && f->depth <= 64 ? f->kinds[f->depth - 1] : 0;
        List own = {0}; /* the places of the names defined here */
        if (tok_is(&toks[i], TK_PUNCT, "{")) {
            char kind = 'o';
            if (i >= 2 && toks[i - 1].kind == TK_IDENT && toks[i - 2].kind == TK_KEYWORD &&
                (!strcmp(toks[i - 2].text, "struct") || !strcmp(toks[i - 2].text, "union")))
                kind = 's';
            else if (i >= 2 && toks[i - 1].kind == TK_IDENT && tok_is(&toks[i - 2], TK_IDENT, "extend"))
                kind = 'x';
            if (f->depth >= 0 && f->depth < 64)
                f->kinds[f->depth] = kind;
            f->depth++;
        } else if (tok_is(&toks[i], TK_PUNCT, "}")) {
            f->depth--;
        } else if (toks[i].kind == TK_IMPORT_K) {
            list_push(&f->imports, file_id(import_path(&toks[i], argv0)));
        } else if (toks[i].kind == TK_IDENT && in == 's' && i + 1 < n && tok_is(&toks[i + 1], TK_PUNCT, ":")) {
            own_skip[i] = true;
        } else if (toks[i].kind == TK_IDENT && in == 'x' && i > 0 && toks[i - 1].kind == TK_KEYWORD &&
                   (!strcmp(toks[i - 1].text, "let") || !strcmp(toks[i - 1].text, "var"))) {
            own_skip[i] = true;
        } else if (f->prelude || f->depth != 0) {
            continue;
        } else if (enum_at(toks, n, i)) {
            int end;
            own = enum_words(toks, n, i, &end);
            list_push(&own, (void *)(intptr_t)(i + 1));
        } else if (defines_type(toks, n, i)) {
            list_push(&own, (void *)(intptr_t)(i + 1));
        } else if (toks[i].kind == TK_KEYWORD && (!strcmp(toks[i].text, "let") || !strcmp(toks[i].text, "var")) &&
                   i + 2 < n && toks[i + 1].kind == TK_IDENT) {
            const Token *after = &toks[i + 2];
            bool variable = tok_is(after, TK_PUNCT, ":") || tok_is(after, TK_PUNCT, "=") || tok_is(after, TK_PUNCT, ":=");
            bool function = tok_is(after, TK_PUNCT, "(");
            if (variable || (function && words && name_in(words, toks[i + 1].text)))
                list_push(&own, (void *)(intptr_t)(i + 1));
        }
        for (int k = 0; k < own.len; k++) {
            const char *name = toks[(int)(intptr_t)own.data[k]].text;
            bool theirs = (types && name_in(types, name)) || (fns && name_in(fns, name)) || (words && name_in(words, name));
            if (theirs && !name_in(&f->sees, name)) {
                list_push(&f->sees, (void *)name);
                any = true;
            }
        }
    }
    for (bool more = any; more;) {
        more = false;
        for (int i = 0; i < src_files.len; i++) {
            SrcFile *f = src_files.data[i];
            for (int k = 0; !f->prelude && k < f->imports.len; k++)
                for (int j = 0; j < src_files.len; j++) {
                    SrcFile *g = src_files.data[j];
                    if (g == f || strcmp(g->id, f->imports.data[k]))
                        continue;
                    for (int s = 0; s < g->sees.len; s++)
                        if (!name_in(&f->sees, g->sees.data[s])) {
                            list_push(&f->sees, g->sees.data[s]);
                            more = true;
                        }
                }
        }
    }
}

/* is the name at i the program's own, which hides the prelude's there?
   Not after Kelvin., nor after another dot, a member's name, nor where it
   declares a member, nor where it is a literal's, $/.../ or 123n, which
   are the prelude's */
static bool own_name(const Token *toks, int i) {
    if (toks[i].kind != TK_IDENT || toks[i].regexp || toks[i].bigint || (i > 0 && tok_is(&toks[i - 1], TK_PUNCT, ".")))
        return false;
    if (own_skip && i < own_skip_n && own_skip[i])
        return false;
    return name_in(&src_file_of(toks[i].pos.file)->sees, toks[i].text);
}

/* A module of the prelude that an #import writes, #import <math>, is
   read where the prelude's is (#601): before all else, as it would be
   were the import not written, and not where the import stands. A
   module's header does not write the prelude's imports, so one that
   names c64 counts on math's being read before it; and BigNum's header
   writes #import <math>, as a program from before #591 may, which put
   math after a header imported before it, whose c64 C then did not know.
   The tokens the import was followed by, the file's and its end, go to
   the front after an import of their own, and the one written stays, an
   import of what is read already */
static Token *prelude_first(Token *toks, int n, int *out_n, const char *path, const char *argv0) {
    *out_n = n;
    char *id = file_id(path);
    int at = -1, end = -1;
    for (int i = 0; i < n && at < 0; i++)
        if (toks[i].kind == TK_IMPORT_K && !strcmp(file_id(import_path(&toks[i], argv0)), id))
            at = i;
    for (int j = at + 1; at >= 0 && j < n && end < 0; j++)
        if (toks[j].kind == TK_FILE_END && !strcmp(file_id(toks[j].text), id))
            end = j;
    if (at < 0 || end < 0)
        return toks;
    bool first = true; /* nothing but imports before it: it is where the prelude's is */
    for (int i = 0; i < at && first; i++)
        first = toks[i].kind == TK_IMPORT || toks[i].kind == TK_IMPORT_K;
    if (first)
        return toks;
    Token imp = {TK_IMPORT_K, toks[0].pos, toks[at].text, toks[0].pos.line, false, false, false, false, true, false};
    Token *all = xmalloc(sizeof(Token) * (size_t)(n + 2));
    int m = 0;
    all[m++] = imp;
    memcpy(all + m, toks + at + 1, sizeof(Token) * (size_t)(end - at));
    m += end - at;
    memcpy(all + m, toks, sizeof(Token) * (size_t)(at + 1));
    m += at + 1;
    memcpy(all + m, toks + end + 1, sizeof(Token) * (size_t)(n - end - 1));
    m += n - end - 1;
    *out_n = m;
    return all;
}

/* The modules of the prelude (#504), which libkelvin holds: a program
   that names one, RegExp, a $/.../ literal's too, imports it as if it
   began with #import <RegExp>, unless it defines a type of that name or
   imports it already; one that does not name it compiles as before.
   UnicodeData is in every program (#520), as String is, but in the
   build of UnicodeData.k itself */
static const char *prelude_names[] = {"UnicodeData", "RegExp", "BigInt", NULL};
static const char *source_name; /* the source's name without its directory and .k, which no prelude imports into itself */

static Token *with_prelude(Token *toks, int n, int *out_n, const char *argv0) {
    const char **names = prelude_names;
    *out_n = n;
    for (int k = 0; names[k]; k++) {
        bool named = false;
        /* a type of the program's own of the name hides the prelude's
           there, and no longer keeps it out (#600): Kelvin.RegExp names
           it, and so does a literal, $/.../ or 123n; the bare name is the
           program's own, where it sees that type */
        List one = {0};
        list_push(&one, (void *)names[k]);
        own_types(toks, n, &one, NULL, NULL, argv0);
        for (int i = 0; i < n && !named; i++)
            named = toks[i].kind == TK_IDENT && !strcmp(toks[i].text, names[k]) && !own_name(toks, i);
        if (!strcmp(names[k], "UnicodeData")) /* (#520) */
            named = !source_name || strcmp(source_name, "UnicodeData");
        Token imp = {TK_IMPORT_K, toks[0].pos, strfmt("<%s>", names[k]), toks[0].pos.line, false, false, false, false,
                     true, false}; /* implied: the prelude's, which a module's header does not write (#520) */
        if (imported_has(import_path(&imp, argv0))) { /* #import <RegExp> written: read first all the same (#601) */
            toks = prelude_first(toks, n, &n, import_path(&imp, argv0), argv0);
            *out_n = n;
            continue;
        }
        if (!named)
            continue;
        if (source_name && !strcmp(source_name, names[k])) /* the module itself, which its own type kept out before (#600) */
            continue;
        int m;
        Token *more = with_imports(&imp, 1, &m, argv0); /* the import, then the module's tokens */
        Token *all = xmalloc(sizeof(Token) * (size_t)(m + n + 1));
        memcpy(all, more, sizeof(Token) * (size_t)m);
        memcpy(all + m, toks, sizeof(Token) * (size_t)n);
        toks = all;
        n += m;
        *out_n = n;
    }
    return toks;
}

/* math is the prelude's too (#590), which libkelvin holds: a program
   that names one of its names imports it as if it began with #import
   <math>; one that names none compiles as before. The names are read
   from the module itself, math.kh, so that none is kept here: what it
   declares, sin, c64, polar, wherever the program writes it but where it
   declares one of its own, let log(...); and what it gives f64 and f32,
   after a dot, f64.tau, x.isnan, 1.0.i. What it gives its own types, z.real,
   needs none: a program has no c64 that does not name one. A type of
   the program's own with one of its types' names, c64, hides math's
   there and names no math (#600), where it kept all of math out: what
   else the program names of it brings it in, and Kelvin.c64 is math's.
   A module of the prelude is built without it, and so is math */
static List math_fns, math_types; /* char *: math's names, read or not: C's math.h declares its functions in every program (#604) */

static Token *with_math(Token *toks, int n, int *out_n, const char *argv0) {
    *out_n = n;
    if (source_name && !strcmp(source_name, "math"))
        return toks;
    const char *dirs[] = {"./modules", kelvin_modules(argv0)};
    char *path = NULL;
    for (int d = 0; d < 2 && !path; d++) {
        if (dirs[d] && kelvin_file(strfmt("%s/math.kh", dirs[d])))
            path = strfmt("%s/math.kh", dirs[d]);
        else if (dirs[d] && kelvin_file(strfmt("%s/math.k", dirs[d])))
            path = strfmt("%s/math.k", dirs[d]);
    }
    if (!path)
        return toks;
    if (imported_has(path)) /* #import <math> written: read first all the same (#601) */
        return prelude_first(toks, n, out_n, path, argv0);
    int m;
    Token *mt = lex(path, read_file(path), &m);
    List names = {0}, types = {0}, members = {0};
    int depth = 0;
    bool giving = false; /* in an extend of a type that is not math's own */
    for (int i = 0; i + 1 < m; i++) {
        const Token *t = &mt[i], *u = &mt[i + 1];
        if (t->kind == TK_PUNCT && !strcmp(t->text, "{"))
            depth++;
        else if (t->kind == TK_PUNCT && !strcmp(t->text, "}"))
            depth--;
        else if (depth == 0 && t->kind == TK_KEYWORD && u->kind == TK_IDENT &&
                 (!strcmp(t->text, "struct") || !strcmp(t->text, "union") || !strcmp(t->text, "enum")))
            list_push(&types, u->text);
        else if (depth == 0 && t->kind == TK_IDENT && !strcmp(t->text, "typealias") && u->kind == TK_IDENT)
            list_push(&types, u->text);
        else if (depth == 0 && t->kind == TK_IDENT && !strcmp(t->text, "extend"))
            giving = !name_in(&types, u->text);
        else if (t->kind == TK_KEYWORD && (!strcmp(t->text, "let") || !strcmp(t->text, "var")) && u->kind == TK_IDENT) {
            if (depth == 0)
                list_push(&names, u->text);
            else if (depth == 1 && giving)
                list_push(&members, u->text);
        }
    }
    bool named = false;
    math_fns = names;
    math_types = types;
    own_types(toks, n, &types, &names, NULL, argv0); /* a type of the program's own with one of its types' names (#600), a variable with one of its functions' (#604) */
    for (int i = 0; i < n && !named; i++) {
        if (toks[i].kind != TK_IDENT)
            continue;
        bool dot = i > 0 && toks[i - 1].kind == TK_PUNCT && !strcmp(toks[i - 1].text, ".");
        bool own = i > 0 && toks[i - 1].kind == TK_KEYWORD &&
                   (!strcmp(toks[i - 1].text, "let") || !strcmp(toks[i - 1].text, "var"));
        if (own || own_name(toks, i)) /* its own c64 names no math; Kelvin.c64 does, and all else of math's */
            continue;
        named = name_in(&names, toks[i].text) || name_in(&types, toks[i].text) ||
                (dot && name_in(&members, toks[i].text));
    }
    if (!named)
        return toks;
    Token imp = {TK_IMPORT_K, toks[0].pos, "<math>", toks[0].pos.line, false, false, false, false, true, false};
    int k;
    Token *more = with_imports(&imp, 1, &k, argv0); /* the import, then the module's tokens */
    Token *all = xmalloc(sizeof(Token) * (size_t)(k + n + 1));
    memcpy(all, more, sizeof(Token) * (size_t)k);
    memcpy(all + k, toks, sizeof(Token) * (size_t)n);
    *out_n = n + k;
    return all;
}

/* The name of the module that an #import of a Kelvin file names, as the
   parser's (#143): <dir/M.k> is M */
static char *module_name(const Token *t) {
    char *name = xstrndup(t->text + 1, strlen(t->text) - 2);
    char *slash = strrchr(name, '/');
    if (slash)
        name = slash + 1;
    if (strrchr(name, '.'))
        *strrchr(name, '.') = 0;
    return name;
}

/* An overlay (#551), as Swift's cross-import overlay: where the modules
   <A> and <B> are both imported, and a file A+B.kh or A+B.k is in
   ./modules or in Kelvin's modules/, it is imported too, as if
   #import <A+B> stood right after the later of the two, whichever the
   program imports first. It holds what A offers of B's types, as math's
   complex number of Rational's BigRat, which a program that imports one
   of them alone neither sees nor compiles; Kelvin has no #if to ask with.
   An overlay imports what it likes, which may bring another overlay in;
   one of an overlay, A+B+C, is not looked for. Written out, #import
   <A+B>, it is a module as any, read once. */
static Token *with_overlays(Token *toks, int n, int *out_n, const char *argv0) {
    const char *dirs[] = {"./modules", kelvin_modules(argv0)};
    List tried = {0}; /* char *: each A+B looked for once */
    for (bool more = true; more;) {
        more = false;
        List names = {0}, ends = {0}; /* the modules, and the token each one's file ends at */
        for (int i = 0; i < n; i++) {
            if (toks[i].kind != TK_IMPORT_K || toks[i].text[0] != '<')
                continue;
            char *name = module_name(&toks[i]);
            bool seen = strchr(name, '+') != NULL;
            for (int k = 0; k < names.len && !seen; k++)
                seen = !strcmp(names.data[k], name);
            if (seen)
                continue;
            char *path = import_path(&toks[i], argv0);
            int end = i; /* read through another path: after its #import */
            for (int j = i + 1; j < n; j++)
                if (toks[j].kind == TK_FILE_END && !strcmp(toks[j].text, path)) {
                    end = j;
                    break;
                }
            list_push(&names, name);
            list_push(&ends, (void *)(intptr_t)end);
        }
        for (int a = 0; a < names.len && !more; a++)
            for (int b = 0; b < names.len && !more; b++) {
                if (a == b)
                    continue;
                char *name = strfmt("%s+%s", (char *)names.data[a], (char *)names.data[b]);
                bool seen = false;
                for (int k = 0; k < tried.len && !seen; k++)
                    seen = !strcmp(tried.data[k], name);
                if (seen)
                    continue;
                list_push(&tried, name);
                char *path = NULL;
                for (int d = 0; d < 2 && !path; d++) {
                    if (dirs[d] && kelvin_file(strfmt("%s/%s.kh", dirs[d], name)))
                        path = strfmt("%s/%s.kh", dirs[d], name);
                    else if (dirs[d] && kelvin_file(strfmt("%s/%s.k", dirs[d], name)))
                        path = strfmt("%s/%s.k", dirs[d], name);
                }
                if (!path || imported_has(path)) /* none, or #import <A+B> written */
                    continue;
                int ea = (int)(intptr_t)ends.data[a], eb = (int)(intptr_t)ends.data[b];
                int at = (ea > eb ? ea : eb) + 1; /* after the later of the two */
                /* and after an overlay put there before (#579): those of one
                   place stand in the order found, so that one may use
                   another's, which it imports */
                while (at < n && toks[at].kind == TK_IMPORT_K && toks[at].implied && strchr(toks[at].text, '+')) {
                    char *put = import_path(&toks[at], argv0);
                    int j = at + 1;
                    while (j < n && !(toks[j].kind == TK_FILE_END && !strcmp(toks[j].text, put)))
                        j++;
                    if (j >= n)
                        break;
                    at = j + 1;
                }
                Token imp = {TK_IMPORT_K, toks[at - 1].pos, strfmt("<%s>", name), toks[at - 1].pos.line, false, false,
                             false, false, true, false}; /* implied, as the prelude's: a module's header does not write it */
                int m;
                Token *over = with_imports(&imp, 1, &m, argv0); /* the import, then the overlay's tokens */
                Token *all = xmalloc(sizeof(Token) * (size_t)(m + n + 1));
                memcpy(all, toks, sizeof(Token) * (size_t)at);
                memcpy(all + at, over, sizeof(Token) * (size_t)m);
                memcpy(all + at + m, toks + at, sizeof(Token) * (size_t)(n - at));
                toks = all;
                n += m;
                more = true; /* its imports may make another pair: look again */
            }
    }
    *out_n = n;
    return toks;
}

/* Kelvin.name (#600) is the prelude's name, whatever the program calls
   its own: what a file of the prelude declares at its top level, a
   function or a type, and print, println and the types that are words,
   Kelvin.String. Kelvin is no name of a program's own.

   It is settled here, in the tokens, once every file is read. Kelvin.T of
   a type is the one token T, and Kelvin.f of a function the one token
   "Kelvin.f", a callee the parser chooses among the prelude's alone, which
   no variable's name hides. And a type of the program's own that has the
   name of one of the prelude's is _kv_own_T in the files that see it
   (own_types), so that the two are two types, to the parser and to C: the
   bare name is the program's there, and the prelude's all else */
static Token *with_kelvin(Token *toks, int n, int *out_n, const char *argv0) {
    static const char *words[] = {"i8",   "i16",  "i32",   "i64",   "i128",       "u8",  "u16",      "u32",    "u64",
                                  "u128", "f32",  "f64",   "bool",  "String",     "cstr", "Bytes",   "Array",  "Dictionary",
                                  "Set",  "Optional", "Result", "Task", "Iterator", "Range", "SYS", NULL};
    List fns = {0}, types = {0};
    /* the words of the prelude's enums of words alone, nfc of NormalForm,
       which are names of every program: each, the token of its enum's
       name, and its number, or NULL where kelvinc does not see it */
    List words_of = {0}, enums_of = {0}, values_of = {0};
    int uses = 0;
    for (int i = 0; i < src_files.len; i++)
        ((SrcFile *)src_files.data[i])->depth = 0;
    for (int i = 0; i + 2 < n; i++) {
        SrcFile *f = src_file_of(toks[i].pos.file);
        uses += tok_is(&toks[i], TK_IDENT, "Kelvin");
        if (!f->prelude)
            continue;
        if (f->depth == 0 && enum_at(toks, n, i)) {
            int end;
            List words = enum_words(toks, n, i, &end);
            long at = 0;
            bool known = true;
            for (int w = 0; w < words.len; w++) {
                int k = (int)(intptr_t)words.data[w];
                if (tok_is(&toks[k + 1], TK_PUNCT, "=")) { /* a number written is its own; any other value kelvinc leaves to C */
                    char *rest = NULL;
                    at = toks[k + 2].kind == TK_NUMBER ? strtol(toks[k + 2].text, &rest, 0) : 0;
                    known = known && rest && !*rest &&
                            (tok_is(&toks[k + 3], TK_PUNCT, ",") || tok_is(&toks[k + 3], TK_PUNCT, ";") || k + 3 >= end ||
                             toks[k + 3].pos.line > toks[k + 2].end_line);
                }
                list_push(&words_of, toks[k].text);
                list_push(&enums_of, &toks[i + 1]);
                list_push(&values_of, known ? strfmt("%ld", at) : NULL);
                at++;
            }
        }
        if (tok_is(&toks[i], TK_PUNCT, "{"))
            f->depth++;
        else if (tok_is(&toks[i], TK_PUNCT, "}"))
            f->depth--;
        else if (f->depth == 0 && defines_type(toks, n, i))
            list_push(&types, toks[i + 1].text);
        else if (f->depth == 0 && toks[i].kind == TK_KEYWORD && (!strcmp(toks[i].text, "let") || !strcmp(toks[i].text, "var")) &&
                 toks[i + 1].kind == TK_IDENT && !tok_is(&toks[i + 2], TK_PUNCT, ".")) /* not static let T.x, a member */
            list_push(&fns, toks[i + 1].text);
    }
    /* math's names hide whether math is read or not (#604): kelvin_prelude.h includes C's math.h, whose exp
       a variable of the program's own named exp would meet in C */
    for (int i = 0; i < math_fns.len; i++)
        list_push(&fns, math_fns.data[i]);
    List hidden = {0}; /* the types' names that hide; types stays those read, which Kelvin.T names */
    for (int i = 0; i < types.len; i++)
        list_push(&hidden, types.data[i]);
    for (int i = 0; i < math_types.len; i++)
        list_push(&hidden, math_types.data[i]);
    own_types(toks, n, &hidden, &fns, &words_of, argv0);
    Token *out = xmalloc(sizeof(Token) * (size_t)(n + 2 * uses + 1));
    int m = 0;
    for (int i = 0; i < n; i++) {
        Token t = toks[i];
        if (t.kind == TK_IDENT && !strncmp(t.text, KV_OWN, strlen(KV_OWN)))
            error_at(t.pos, "names starting with _kv_ are kelvinc's own, in the C it writes: rename '%s'", t.text);
        if (!tok_is(&t, TK_IDENT, "Kelvin")) {
            if (own_name(toks, i)) {
                if (!name_in(&kv_own_names, t.text))
                    list_push(&kv_own_names, t.text);
                t.text = strfmt(KV_OWN "%s", t.text);
            }
            out[m++] = t;
            continue;
        }
        bool member = i > 0 && tok_is(&toks[i - 1], TK_PUNCT, ".");
        bool dotted = i + 2 < n && tok_is(&toks[i + 1], TK_PUNCT, ".") &&
                      (toks[i + 2].kind == TK_IDENT || toks[i + 2].kind == TK_KEYWORD);
        if (member || !dotted)
            error_at(t.pos, "'Kelvin' is the prelude's name (#600), as in 'Kelvin.log(x)', the prelude's log whatever "
                            "the program calls its own: a name of the program's own is another, as 'kelvin'");
        Token x = toks[i + 2];
        bool call = i + 3 < n && tok_is(&toks[i + 3], TK_PUNCT, "(");
        bool word = false;
        for (int k = 0; x.kind == TK_KEYWORD && words[k]; k++)
            word = word || !strcmp(words[k], x.text);
        if (x.kind == TK_KEYWORD && !word)
            error_at(x.pos, "'Kelvin.%s' names nothing: '%s' is a word of the language, and not a name of the prelude's "
                            "(#600)", x.text, x.text);
        if (x.kind == TK_KEYWORD || !strcmp(x.text, "print") || !strcmp(x.text, "println"))
            ; /* a word, which no program defines: the same with and without */
        else if (name_in(&fns, x.text) && (call || !name_in(&types, x.text)))
            x.text = strfmt(KV_NS "%s", x.text); /* the prelude's function, the parser's to choose */
        else if (!name_in(&types, x.text) && name_in(&words_of, x.text)) {
            /* a word of an enum of the prelude's, Kelvin.nfc: (0 as NormalForm), its number as its type, which
               a variable of its name hides neither here nor in C */
            int w = 0;
            while (strcmp(words_of.data[w], x.text))
                w++;
            if (!values_of.data[w])
                error_at(x.pos, "'Kelvin.%s' is a word of the prelude's enum %s whose number kelvinc does not see: "
                                "not yet (#600)", x.text, ((Token *)enums_of.data[w])->text);
            Token part = x;
            part.kind = TK_PUNCT, part.text = "(";
            out[m++] = part;
            part.kind = TK_NUMBER, part.text = values_of.data[w];
            out[m++] = part;
            part.kind = TK_KEYWORD, part.text = "as";
            out[m++] = part;
            part.kind = TK_IDENT, part.text = ((Token *)enums_of.data[w])->text;
            out[m++] = part;
            part.kind = TK_PUNCT, part.text = ")";
            out[m++] = part;
            i += 2;
            continue;
        } else if (!name_in(&types, x.text))
            error_at(x.pos, "'Kelvin.%s' names nothing: the prelude has no '%s' at its top level (#600); Kelvin.name is "
                            "a function or a type that a program has with no import, as 'Kelvin.sqrt' and 'Kelvin.BigInt'",
                     x.text, x.text);
        out[m++] = x; /* where the name is, which a library's header is written from */
        i += 2;
    }
    *out_n = m;
    return out;
}

static List lib_objects; /* --lib: the .o and .a files given after the source, into libkM too (#156) */
static List link_objects; /* the .o and .a files linked into the program (#281) */

/* ---------- linking objects (#281) ---------- */

/* A module with a library, M.kh, and the modules it imports */
typedef struct {
    char *name, *path;
    List deps;
    bool seen;
} Module;

static List modules_found;

static Module *module_named(const char *name) {
    for (int i = 0; i < modules_found.len; i++)
        if (!strcmp(((Module *)modules_found.data[i])->name, name))
            return modules_found.data[i];
    return NULL;
}

/* Every M.kh in ./modules and Kelvin's modules/, the first of a name, as
   #import <M> finds it, with the modules its #import <N> lines name */
static void find_modules(const char *argv0) {
    const char *dirs[] = {"./modules", kelvin_modules(argv0)};
    for (int i = 0; i < 2; i++) {
        DIR *d = dirs[i] ? opendir(dirs[i]) : NULL;
        if (!d)
            continue;
        for (struct dirent *e; (e = readdir(d));) {
            size_t n = strlen(e->d_name);
            if (n < 4 || strcmp(e->d_name + n - 3, ".kh"))
                continue;
            char *name = xstrndup(e->d_name, n - 3);
            if (module_named(name))
                continue;
            Module *m = xcalloc(1, sizeof *m);
            m->name = name;
            m->path = strfmt("%s/%s", dirs[i], e->d_name);
            for (char *line = read_file(m->path); line; line = strchr(line, '\n') ? strchr(line, '\n') + 1 : NULL) {
                if (strncmp(line, "#import <", 9))
                    continue;
                char *end = strchr(line + 9, '>');
                char *dep = end ? xstrndup(line + 9, (size_t)(end - line - 9)) : NULL;
                if (dep && !strchr(dep, '.') && !strchr(dep, '\n'))
                    list_push(&m->deps, dep);
            }
            list_push(&modules_found, m);
        }
        closedir(d);
    }
}

/* m after the modules it imports */
static void visit_module(Module *m, List *order) {
    if (m->seen)
        return;
    m->seen = true;
    for (int i = 0; i < m->deps.len; i++) {
        Module *d = module_named(m->deps.data[i]);
        if (d)
            visit_module(d, order);
    }
    list_push(order, m);
}

/* Objects may call any module, which their imports no longer show: the
   libraries of all, each before the ones it imports, so that C's linker,
   reading them once in order, finds what one calls in one after it. A
   static library brings in only what is called. */
static void all_module_libs(const char *argv0) {
    find_modules(argv0);
    List order = {0};
    for (int i = 0; i < modules_found.len; i++)
        visit_module(modules_found.data[i], &order);
    module_libs.len = 0;
    module_marks.len = 0;
    for (int i = order.len - 1; i >= 0; i--)
        module_library(((Module *)order.data[i])->path);
}

static bool ends_with(const char *s, const char *suffix) {
    size_t n = strlen(s), m = strlen(suffix);
    return n >= m && !strcmp(s + n - m, suffix);
}

/* the shared library beside a static one, libx.dylib or libx.so for
   libx.a, where there is one; else the static one */
static char *shared_of(const char *a) {
    size_t n = strlen(a);
    if (n < 3 || strcmp(a + n - 2, ".a"))
        return xstrdup(a);
    const char *exts[] = {".dylib", ".so"};
    for (int i = 0; i < 2; i++) {
        char *so = strfmt("%.*s%s", (int)(n - 2), a, exts[i]);
        if (file_exists(so))
            return so;
    }
    return xstrdup(a);
}

/* libkM.dylib or libkM.so from the module's object (#147): linked against
   the shared libkelvin and the shared libraries of the modules it imports,
   or their static ones where there is no shared one */
static int link_shared(const char *cc, const char *lib_dir, const char *lib_name, const char *obj, const char *rt_inc,
                       const char *rt_lib, bool verbose) {
    List args = {0};
    list_push(&args, (void *)cc);
#ifdef __APPLE__
    char *so = strfmt("%s/libk%s.dylib", lib_dir, lib_name);
    list_push(&args, "-dynamiclib");
    list_push(&args, "-install_name");
    list_push(&args, strfmt("@rpath/libk%s.dylib", lib_name));
#else
    char *so = strfmt("%s/libk%s.so", lib_dir, lib_name);
    list_push(&args, "-shared");
    list_push(&args, strfmt("-Wl,-soname,libk%s.so", lib_name));
#endif
    list_push(&args, "-o");
    list_push(&args, so);
    list_push(&args, (void *)obj);
    for (int i = 0; i < lib_objects.len; i++)
        list_push(&args, lib_objects.data[i]);
    if (is_dir("./modules"))
        list_push(&args, "-L./modules");
    list_push(&args, strfmt("-L%s", rt_inc));
    for (int i = 0; i < module_libs.len; i++)
        list_push(&args, shared_of(module_libs.data[i]));
    link_flags(lib_dir, lib_name, &args); /* its own system libraries (#482) */
    list_push(&args, shared_of(rt_lib));
    list_push(&args, "-lm");
    list_push(&args, "-lpthread"); /* a Task's thread (#312) */
    list_push(&args, NULL);
    unlink(so);
    return run((char **)args.data, verbose);
}

static bool text_in(List *l, const char *s) {
    for (int i = 0; i < l->len; i++)
        if (!strcmp(l->data[i], s))
            return true;
    return false;
}

static char *default_output(const char *src) {
    const char *base = strrchr(src, '/');
    base = base ? base + 1 : src;
    size_t n = strlen(base);
    if (n > 2 && !strcmp(base + n - 2, ".k"))
        n -= 2;
    return xstrndup(base, n);
}

/* kelvinc -o program a.o b.o (#281): objects kelvinc -c made, and .a
   files, linked with the libraries of all modules and libkelvin; the
   program is named after the first object without -o */
static int link_only(const char *argv0, const char *out_path, bool run_after, bool verbose, int prog_argc,
                     char **prog_argv) {
    char *rt_inc, *rt_lib;
    find_runtime(argv0, &rt_inc, &rt_lib, true);
    all_module_libs(argv0);
    char *dir = NULL;
    if (run_after && !out_path) {
        const char *tmpdir = getenv("TMPDIR");
        dir = strfmt("%s/kelvinc-XXXXXX", tmpdir && *tmpdir ? tmpdir : "/tmp");
        if (!mkdtemp(dir))
            fatal("cannot create a temporary directory");
    }
    const char *first = link_objects.data[0];
    char *exe = out_path ? xstrdup(out_path) : dir ? strfmt("%s/program", dir) : default_output(first);
    if (!out_path && !dir) /* a.o is a, as file.k is file */
        exe[strlen(exe) - 2] = '\0';
    const char *cc = getenv("CC");
    List args = {0};
    list_push(&args, (void *)(cc && *cc ? cc : "cc"));
    list_push(&args, "-o");
    list_push(&args, exe);
    for (int i = 0; i < link_objects.len; i++)
        list_push(&args, link_objects.data[i]);
    if (is_dir("./modules"))
        list_push(&args, "-L./modules");
    list_push(&args, strfmt("-L%s", rt_inc));
    const char *extra = getenv("KELVIN_CFLAGS"); /* -fsanitize=address links its runtime too */
    char *flags = xstrdup(extra ? extra : "");
    for (char *tok = strtok(flags, " \t\n"); tok; tok = strtok(NULL, " \t\n"))
        list_push(&args, tok);
    for (int i = 0; i < module_libs.len; i++)
        list_push(&args, module_libs.data[i]);
    list_push(&args, rt_lib);
    list_push(&args, "-lm");
    list_push(&args, "-lpthread"); /* a Task's thread (#312) */
    list_push(&args, NULL);
    int rc = run((char **)args.data, verbose);
    if (rc != 0 || !run_after) {
        if (dir)
            rmdir(dir);
        return rc;
    }
    char **pargv = xcalloc((size_t)prog_argc + 2, sizeof(char *));
    pargv[0] = exe;
    for (int i = 0; i < prog_argc; i++)
        pargv[i + 1] = prog_argv[i];
    rc = run(pargv, false);
    if (dir) {
        unlink(exe);
        rmdir(dir);
    }
    return rc;
}

int main(int argc, char **argv) {
    const char *src_path = NULL, *out_path = NULL;
    bool emit_c = false, run_after = false, optimize = false, debug = false, verbose = false, compile_only = false;
    bool line_directives = true, lib = false, prelude_lib = false; /* --prelude (#504) */
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
        } else if (!strcmp(a, "-c")) {
            compile_only = true;
        } else if (!strcmp(a, "--runtime")) {
            compile_only = true; /* an object of the runtime (#289) */
            runtime_mode = true;
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
        } else if (!strcmp(a, "--lib")) {
            lib = true;
            lib_mode = true;
        } else if (!strcmp(a, "--prelude")) { /* a module libkelvin holds, RegExp and UnicodeData (#504) */
            lib = true;
            lib_mode = true;
            prelude_lib = true;
            prelude_mode = true;
        } else if (!strcmp(a, "--version")) {
            printf("kelvinc %s\n", KELVIN_VERSION);
            return 0;
        } else if (!strcmp(a, "-h") || !strcmp(a, "--help")) {
            usage(stdout);
            return 0;
        } else if (a[0] == '-') {
            usage(stderr);
            fatal("unknown option '%s'", a);
        } else if (src_path && lib && (ends_with(a, ".o") || ends_with(a, ".a"))) {
            list_push(&lib_objects, a); /* an object or an archive the library holds too (#156) */
        } else if (!lib && (ends_with(a, ".o") || ends_with(a, ".a"))) {
            list_push(&link_objects, a); /* linked into the program (#281) */
        } else if (src_path) {
            fatal("only one source file is supported for now");
        } else {
            src_path = a;
        }
    }
    if (runtime_mode && emit_c) /* --runtime --emit-c: the runtime file's C (#289) */
        compile_only = false;
    if (runtime_mode && (lib || run_after || link_objects.len))
        fatal("--runtime makes an object of the runtime, which %s does not",
              lib ? "--lib" : run_after ? "--run" : "linking objects");
    if (compile_only && (lib || emit_c || run_after))
        fatal("-c makes an object, which %s does not", lib ? "--lib" : emit_c ? "--emit-c" : "--run");
    if (compile_only && link_objects.len)
        fatal("-c compiles one source into an object, and links nothing: '%s' is linked without -c",
              (char *)link_objects.data[0]);
    if (!src_path && link_objects.len && !emit_c && !compile_only)
        return link_only(argv[0], out_path, run_after, verbose, prog_argc, prog_argv);
    if (!src_path) {
        usage(stderr);
        return 2;
    }

    char *src = read_file(src_path);
    set_source(src_path, src);
    int ntoks;
    Token *toks = lex(src_path, src, &ntoks);
    if (lib) /* a library's functions are named by their types, as a program's prototypes of them are (#146) */
        for (int i = 0; i < ntoks; i++)
            toks[i].imported = true;
    imported_already(src_path); /* the main file is brought in already */
    toks = with_imports(toks, ntoks, &ntoks, argv[0]);
    if (!runtime_mode) {
        const char *base = strrchr(src_path, '/');
        source_name = default_output(base ? base + 1 : src_path);
        if (!prelude_mode)
            toks = with_math(toks, ntoks, &ntoks, argv[0]); /* math, if one of its names is named (#590) */
        toks = with_prelude(toks, ntoks, &ntoks, argv[0]); /* RegExp, if named (#504); UnicodeData (#520) */
        toks = with_overlays(toks, ntoks, &ntoks, argv[0]); /* <A+B>, where <A> and <B> are both imported (#551) */
        toks = with_kelvin(toks, ntoks, &ntoks, argv[0]); /* Kelvin.name, and the program's own types of the prelude's names (#600) */
    }
    Program *prog = parse(toks, ntoks);
    char *c_code = gen_program(prog, line_directives);
    if (link_objects.len) /* the objects may call modules the source does not import (#281) */
        all_module_libs(argv[0]);
    char *lib_dir = NULL, *lib_name = NULL;
    if (lib) {
        /* M.kh and libkM.a, in ./modules or the directory -o names */
        lib_dir = out_path ? xstrdup(out_path) : xstrdup("./modules");
        if (!is_dir(lib_dir) && mkdir(lib_dir, 0777) != 0)
            fatal("cannot create '%s'", lib_dir);
        lib_name = default_output(src_path);
        const char *base = strrchr(lib_name, '/');
        if (base)
            lib_name = xstrdup(base + 1);
        bool named = false; /* RegExp, brought in where a program names it */
        for (int i = 0; prelude_names[i]; i++)
            named = named || !strcmp(prelude_names[i], lib_name);
        char *kh = prelude_lib
                       ? strfmt("// %s.kh - the module %s of the prelude (#504), made by kelvinc --prelude from %s: its\n"
                                "// declarations, the bodies dropped, which libkelvin defines; %s\n%s",
                                lib_name, lib_name, src_path,
                                !strcmp(lib_name, "UnicodeData") ? "every program has it, as it has String (#520)"
                                : named ? strfmt("a program that names %s brings it in, as #import <%s> does", lib_name,
                                                 lib_name)
                                        : strfmt("#import <%s> brings it in", lib_name),
                                gen_header(prog))
                       : strfmt("// %s.kh - the module %s (#146), made by kelvinc --lib from %s: its declarations,\n"
                                "// the bodies dropped, which libk%s.a beside it defines; #import <%s> brings it in\n%s",
                                lib_name, lib_name, src_path, lib_name, lib_name, gen_header(prog));
        write_file(strfmt("%s/%s.kh", lib_dir, lib_name), kh);
    }

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
    find_runtime(argv[0], &rt_inc, &rt_lib, !lib && !compile_only);
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
        /* a converter's clamp (#513) compares a value with T's limits, which
           an enum or an int may never reach: clang's note of it, not ours */
        "-Wno-tautological-constant-out-of-range-compare",
        /* gcc on x86-64 notes that passing a struct with a flexible array
           member changed ABI in GCC 4.4, e.g. for a derived .cstr */
        "-Wno-psabi",
        /* a * b + c is rounded twice, as gcc does in ISO C mode, where
           clang would fuse it into one fma(): the same results from both,
           and z * w == w * z in modules/math.k (#43) */
        "-ffp-contract=off",
    };
    List cc_args = {0};
    for (size_t i = 0; i < sizeof base_args / sizeof base_args[0]; i++)
        list_push(&cc_args, (void *)base_args[i]);
    /* #import "x.h" as C looks next to the .k file, as #include would */
    const char *slash = strrchr(src_path, '/');
    list_push(&cc_args, !slash ? "-I." : slash == src_path ? "-I/" : strfmt("-I%.*s", (int)(slash - src_path), src_path));
    /* C looks for headers and libraries in ./modules and Kelvin's modules/
       too (#46), where the prelude header is a system header: its macros
       raise no warnings. A ./modules with a prelude header of its own,
       another Kelvin's, comes after the system's, so that the header is
       the one of the libkelvin.a linked. */
    char *here = realpath("./modules", NULL), *home = realpath(rt_inc, NULL);
    if (here && is_dir(here) && !(home && !strcmp(here, home))) {
        list_push(&cc_args, file_exists("./modules/kelvin_prelude.h") ? "-idirafter" : "-I");
        list_push(&cc_args, "./modules");
        list_push(&cc_args, "-L./modules");
    }
    list_push(&cc_args, "-isystem");
    list_push(&cc_args, rt_inc);
    list_push(&cc_args, strfmt("-L%s", rt_inc));
    char *obj_path = prelude_lib ? strfmt("%s/%s.o", lib_dir, lib_name) /* for libkelvin (#504) */
                                 : strfmt("%s/libk%s.o", dir, lib_name ? lib_name : "");
    if (lib) { /* an object, then libkM.a from it (#146) */
        list_push(&cc_args, "-c");
        list_push(&cc_args, "-fPIC");
        list_push(&cc_args, "-o");
        list_push(&cc_args, obj_path);
    } else if (compile_only) { /* an object, file.o or the -o path (#281) */
        list_push(&cc_args, "-c");
        if (runtime_mode) /* into libkelvin's shared library too (#289) */
            list_push(&cc_args, "-fPIC");
        list_push(&cc_args, "-o");
        list_push(&cc_args, out_path ? xstrdup(out_path) : strfmt("%s.o", default_output(src_path)));
    } else {
        list_push(&cc_args, "-o");
        list_push(&cc_args, exe);
    }
    list_push(&cc_args, c_path);
    for (int i = 0; i < link_objects.len; i++) /* after the program's C, before the libraries (#281) */
        list_push(&cc_args, link_objects.data[i]);
    /* extra flags, split on whitespace (e.g. -fsanitize=undefined), after
       the program, so that a -lfoo there links what it uses (#46) */
    const char *extra = getenv("KELVIN_CFLAGS");
    char *flags = xstrdup(extra ? extra : "");
    for (char *tok = strtok(flags, " \t\n"); tok; tok = strtok(NULL, " \t\n"))
        list_push(&cc_args, tok);
    for (int i = 0; i < module_libs.len; i++) /* the modules' libraries (#143), before libkelvin, which they use */
        list_push(&cc_args, module_libs.data[i]);
    const char *tail_args[] = {rt_lib, "-lm", "-lpthread", NULL}; /* -lpthread: a Task's thread (#312) */
    for (size_t i = 0; i < sizeof tail_args / sizeof tail_args[0]; i++)
        list_push(&cc_args, (void *)tail_args[i]);
    if (lib || compile_only) { /* no libraries: an object only; the list ends with NULL */
        if (cc_args.len && !cc_args.data[cc_args.len - 1])
            cc_args.len--;
        while (cc_args.len && (cc_args.data[cc_args.len - 1] == (void *)rt_lib ||
                               !strcmp(cc_args.data[cc_args.len - 1], "-lm") ||
                               !strcmp(cc_args.data[cc_args.len - 1], "-lpthread") ||
                               text_in(&module_libs, cc_args.data[cc_args.len - 1])))
            cc_args.len--;
        int kept = 0;
        for (int i = 0; i < cc_args.len; i++) /* and no -L: nothing is linked */
            if (strncmp(cc_args.data[i], "-L", 2))
                cc_args.data[kept++] = cc_args.data[i];
        cc_args.len = kept;
        list_push(&cc_args, NULL);
    }
    char **cc_argv = (char **)cc_args.data;
    int rc = run(cc_argv, verbose);
    unlink(c_path);
    if (rc != 0) {
        rmdir(dir);
        return rc;
    }
    if (prelude_lib) { /* the object stays, for libkelvin; no libkM (#504) */
        rmdir(dir);
        return rc;
    }
    if (lib) {
        char *a = strfmt("%s/libk%s.a", lib_dir, lib_name);
        unlink(a);
        List ar_args = {0};
        list_push(&ar_args, "ar");
        list_push(&ar_args, "rcs");
        list_push(&ar_args, a);
        list_push(&ar_args, obj_path);
        for (int i = 0; i < lib_objects.len; i++)
            if (ends_with(lib_objects.data[i], ".o"))
                list_push(&ar_args, lib_objects.data[i]);
        list_push(&ar_args, NULL);
        rc = run((char **)ar_args.data, verbose);
        if (rc == 0) /* and the shared libkM, for C and other toolchains (#147) */
            rc = link_shared(cc_argv[0], lib_dir, lib_name, obj_path, rt_inc, rt_lib, verbose);
        unlink(obj_path);
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
