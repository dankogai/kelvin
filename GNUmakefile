# GNUmakefile - the build, GNU make's, which GNU make reads before Makefile;
# BSD make reads Makefile, which hands each target here, to gmake (#193)
CC ?= cc
CFLAGS ?= -std=c11 -O2 -g -Wall -Wextra -Wno-unused-parameter
# The runtime has its own flags: kelvinc may be built with sanitizers or
# -Werror, but every Kelvin program links libkelvin.
RT_CFLAGS ?= -std=c11 -O2 -g -Wall -Wextra -fPIC
PREFIX ?= /usr/local

SRCS := $(wildcard src/*.c)
OBJS := $(SRCS:src/%.c=build/%.o)
UD_SRCS := runtime/unicode_data.c runtime/unicode_tables.c runtime/unicode_names.c
UD_OBJS := $(UD_SRCS:runtime/%.c=build/runtime/%.o)
RT_SRCS := $(filter-out runtime/io.c runtime/os.c runtime/regexp.c runtime/regexp_parse.c runtime/fetch.c $(UD_SRCS), $(wildcard runtime/*.c))
RT_OBJS := $(RT_SRCS:runtime/%.c=build/runtime/%.o)
# the runtime written in Kelvin (#289): kelvinc --runtime makes an object of
# each runtime/*.k, whose kv_ functions keep the names kelvin_prelude.h declares
RT_K_SRCS := $(filter-out runtime/os.k, $(wildcard runtime/*.k))
# libkOS's: runtime/os.k beside runtime/os.c (#301)
OS_K_OBJ := build/runtime/os_k.o
RT_K_OBJS := $(RT_K_SRCS:runtime/%.k=build/runtime/%_k.o)
# IO and OS are modules (#144, #145): #import <IO> and #import <OS> bring in
# modules/IO.kh and OS.kh, whose C headers are kIO.h and kOS.h, and link
# libkIO and libkOS, the .kh + libkM form of a module (#143)
MOD_LIBS := modules/libkIO.a modules/libkOS.a
# UnicodeData (#156) is written in Kelvin over its C tables, the objects of
# runtime/unicode_*.c, which tools/gen_unicode.py makes from tools/ucd/; RegExp
# (#157) over its engine, runtime/regexp*.c, on UnicodeData. Both are modules of
# the prelude (#504): kelvinc --prelude makes each one's M.kh and object, which
# libkelvin holds with their C, so a program links them only where it uses them;
# optimized (-O -g), as the runtime is, and so are the modules of --lib (#518)
RX_OBJS := build/runtime/regexp.o build/runtime/regexp_parse.o
PRELUDE_OBJS := build/prelude/UnicodeData.o build/prelude/RegExp.o build/prelude/BigInt.o
# JSON (#113) is built by kelvinc --lib from modules/JSON.k alone (#484), so that a
# module such as fetch may import it, which a source included twice would not let
KELVIN_LIBS := modules/UnicodeData.kh modules/RegExp.kh modules/BigInt.kh modules/JSON.kh modules/fetch.kh modules/localStorage.kh
# fetch (#482) is written in Kelvin over runtime/fetch.c, an HTTP/1.1 client;
# HTTPS is OpenSSL's where HAS_SSL=1, the default, which make HAS_SSL=0 or the
# environment turns off. tools/ssl-flags.sh finds OpenSSL (SSL_CFLAGS and
# SSL_LIBS may say where), and modules/libkfetch.link hands its flags to the
# link of each program that imports <fetch>
HAS_SSL ?= 1
ifeq ($(HAS_SSL),1)
SSL_CFLAGS_FOUND := $(shell CC="$(CC)" sh tools/ssl-flags.sh --cflags)
SSL_LIBS_FOUND := $(shell CC="$(CC)" sh tools/ssl-flags.sh --libs)
FETCH_CFLAGS := -DKV_HAS_SSL $(SSL_CFLAGS_FOUND)
else
SSL_LIBS_FOUND :=
FETCH_CFLAGS :=
endif
# the flags a program that imports <fetch> links with, written as make reads
# this, before it weighs what to build: where they change, libkfetch is built
# again, its outputs removed, since a make of whole seconds may see a new
# libkfetch.link and an old object as made at once
FETCH_LINK := $(shell mkdir -p modules build/runtime; printf '%s\n' "$(SSL_LIBS_FOUND)" > modules/libkfetch.link.tmp; \
    if cmp -s modules/libkfetch.link.tmp modules/libkfetch.link; then rm -f modules/libkfetch.link.tmp; \
    else mv modules/libkfetch.link.tmp modules/libkfetch.link; rm -f build/runtime/fetch.o modules/fetch.kh modules/libkfetch.a; fi)

# modules/ holds what a Kelvin program uses: the prelude header, libkelvin
# and the Kelvin files of #import <x.k> (#46)
ifeq ($(shell uname -s),Darwin)
SO := dylib
SHLIB_FLAGS = -dynamiclib -install_name @rpath/$(notdir $@)
else
SO := so
SHLIB_FLAGS = -shared -Wl,-soname,$(notdir $@)
endif
SHLIB := libkelvin.$(SO)
MOD_SHLIBS := modules/libkIO.$(SO) modules/libkOS.$(SO)

all: kelvinc modules/libkelvin.a modules/$(SHLIB) $(MOD_LIBS) $(MOD_SHLIBS) $(KELVIN_LIBS) modules/Rational.k

# kelvinc checks a $/.../ literal (#163) with the pattern parser of RegExp and the Unicode tables;
# it works out a power of two literals with libm's pow (#380)
CHECK_OBJS := build/runtime/regexp_parse.o build/runtime/unicode_tables.o
kelvinc: $(OBJS) $(CHECK_OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(CHECK_OBJS) -lm

build/%.o: src/%.c src/kelvin.h | build
	$(CC) $(CFLAGS) -c -o $@ $<

build/runtime/%.o: runtime/%.c modules/kelvin_prelude.h modules/kIO.h modules/kOS.h | build/runtime
	$(CC) $(RT_CFLAGS) -Imodules -c -o $@ $<

build/runtime/%_k.o: runtime/%.k kelvinc modules/kelvin_prelude.h | build/runtime
	CC="$(CC)" ./kelvinc --runtime -O -g $< -o $@

# the runtime and the modules of the prelude (#504); the libraries they were
# before, libkUnicodeData and libkRegExp, removed where an older build left them
modules/libkelvin.a: $(RT_OBJS) $(RT_K_OBJS) $(UD_OBJS) $(RX_OBJS) $(PRELUDE_OBJS)
	rm -f $@ modules/libkUnicodeData.* modules/libkRegExp.*
	ar rcs $@ $(RT_OBJS) $(RT_K_OBJS) $(UD_OBJS) $(RX_OBJS) $(PRELUDE_OBJS)

modules/$(SHLIB): $(RT_OBJS) $(RT_K_OBJS) $(UD_OBJS) $(RX_OBJS) $(PRELUDE_OBJS)
	$(CC) $(SHLIB_FLAGS) -o $@ $(RT_OBJS) $(RT_K_OBJS) $(UD_OBJS) $(RX_OBJS) $(PRELUDE_OBJS) -lm -lpthread

modules/libkIO.a: build/runtime/io.o
	rm -f $@
	ar rcs $@ $<

$(OS_K_OBJ): modules/kOS.h

modules/libkOS.a: build/runtime/os.o $(OS_K_OBJ)
	rm -f $@
	ar rcs $@ build/runtime/os.o $(OS_K_OBJ)

modules/libkOS.$(SO): build/runtime/os.o $(OS_K_OBJ) modules/$(SHLIB)
	$(CC) $(SHLIB_FLAGS) -o $@ build/runtime/os.o $(OS_K_OBJ) -Lmodules -lkelvin

modules/libkIO.$(SO): build/runtime/io.o modules/libkOS.$(SO) modules/$(SHLIB)
	$(CC) $(SHLIB_FLAGS) -o $@ $< -Lmodules -lkOS -lkelvin

build/runtime/unicode_%.o: runtime/unicode_%.c modules/kelvin_prelude.h modules/kUnicodeData.h | build/runtime
	$(CC) $(RT_CFLAGS) -Wno-overlength-strings -Imodules -c -o $@ $<

# the tables, from the Unicode Character Database in tools/ucd/ (#156)
runtime/unicode_tables.c runtime/unicode_names.c: tools/gen_unicode.py $(wildcard tools/ucd/*.txt)
	python3 -I tools/gen_unicode.py

# the codepoints of a name past ASCII (#385), kelvinc's and kc's
src/ident.c selfhost/ident.k: tools/gen_ident.py tools/ucd/DerivedCoreProperties.txt tools/ucd/emoji-data.txt
	python3 -I tools/gen_ident.py

# the module of #import <Rational>, its four widths written out from one text (#541)
modules/Rational.k: tools/gen_rational.py
	python3 -I tools/gen_rational.py

# a module of the prelude (#504): its M.kh into modules/, its object for libkelvin
build/prelude/UnicodeData.o: modules/UnicodeData.k modules/kUnicodeData.h modules/kelvin_prelude.h kelvinc
	./kelvinc --prelude -O -g modules/UnicodeData.k -o build/prelude
	cp build/prelude/UnicodeData.kh modules/UnicodeData.kh
modules/UnicodeData.kh: build/prelude/UnicodeData.o

build/runtime/regexp%.o: runtime/regexp%.c runtime/regexp_internal.h modules/kelvin_prelude.h modules/kUnicodeData.h modules/kRegExp.h | build/runtime
	$(CC) $(RT_CFLAGS) -Imodules -c -o $@ $<
build/prelude/RegExp.o: modules/RegExp.k modules/kRegExp.h modules/UnicodeData.kh modules/kelvin_prelude.h kelvinc
	./kelvinc --prelude -O -g modules/RegExp.k -o build/prelude
	cp build/prelude/RegExp.kh modules/RegExp.kh
modules/RegExp.kh: build/prelude/RegExp.o

# BigInt (#507), integers of any size, written in Kelvin alone, on the
# header of UnicodeData, which every build brings in (#520): before it is
# made, make -j would compile UnicodeData.k into BigInt.o too (#526)
build/prelude/BigInt.o: modules/BigInt.k modules/UnicodeData.kh modules/kelvin_prelude.h kelvinc
	./kelvinc --prelude -O -g modules/BigInt.k -o build/prelude
	cp build/prelude/BigInt.kh modules/BigInt.kh
modules/BigInt.kh: build/prelude/BigInt.o

build/runtime/fetch.o: runtime/fetch.c modules/kelvin_prelude.h modules/kfetch.h modules/libkfetch.link | build/runtime
	@if [ "$(HAS_SSL)" = 1 ] && [ -z "$(SSL_LIBS_FOUND)" ]; then \
	    echo "HAS_SSL=1, but no OpenSSL that $(CC) compiles and links was found: install it (libssl-dev, openssl), say where with SSL_CFLAGS and SSL_LIBS, or build with HAS_SSL=0, with no HTTPS" >&2; exit 1; fi
	$(CC) $(RT_CFLAGS) $(FETCH_CFLAGS) -Imodules -c -o $@ $<
modules/JSON.kh: modules/JSON.k kelvinc modules/libkelvin.a modules/$(SHLIB)
	./kelvinc --lib -O -g modules/JSON.k -o modules
# localStorage (#491), JS's, a program's text kept in a JSON file between runs
modules/localStorage.kh: modules/localStorage.k modules/JSON.kh $(MOD_LIBS) kelvinc modules/libkelvin.a modules/$(SHLIB)
	./kelvinc --lib -O -g modules/localStorage.k -o modules
modules/fetch.kh: modules/fetch.k build/runtime/fetch.o modules/libkfetch.link modules/JSON.kh kelvinc modules/libkelvin.a modules/$(SHLIB)
	./kelvinc --lib -O -g modules/fetch.k build/runtime/fetch.o -o modules

build build/runtime:
	mkdir -p $@

test: all
	./tests/run.sh
	./tests/fetch.sh
	./tests/docs.sh
	@if command -v node >/dev/null 2>&1; then node tests/grammar.js; else echo "tests/grammar.js skipped: no node"; fi

# every test program under AddressSanitizer with a counting allocator (#175)
asan: all
	./tests/asan.sh

# the VS Code extension of editors/vscode (#191): make vsix packages it as
# build/kelvin-lang-<version>.vsix with tools/vsix.sh, make vscode installs
# that with VS Code's code command, again over an installed one
vsix:
	./tools/vsix.sh

vscode:
	@command -v code >/dev/null 2>&1 || { echo "make vscode: no code command; in VS Code, run 'Shell Command: Install 'code' command in PATH'"; exit 1; }
	code --install-extension "$$(./tools/vsix.sh)" --force

install: all
	install -d $(PREFIX)/bin $(PREFIX)/lib/kelvin/modules
	install -m 755 kelvinc $(PREFIX)/bin/kelvinc
	install -m 644 modules/kelvin_prelude.h modules/kIO.h modules/kOS.h modules/kUnicodeData.h modules/kRegExp.h modules/kfetch.h modules/libkelvin.a $(MOD_LIBS) modules/libkJSON.a modules/libklocalStorage.a modules/libkfetch.a modules/libkfetch.link modules/*.k modules/*.kh $(PREFIX)/lib/kelvin/modules/
	install -m 755 modules/$(SHLIB) $(MOD_SHLIBS) modules/libkJSON.$(SO) modules/libklocalStorage.$(SO) modules/libkfetch.$(SO) $(PREFIX)/lib/kelvin/modules/

clean:
	rm -rf build kelvinc modules/libkelvin.a modules/libk*.so modules/libk*.dylib modules/libkIO.a modules/libkOS.a modules/libkUnicodeData.a modules/UnicodeData.kh modules/libkRegExp.a modules/RegExp.kh modules/BigInt.kh modules/libkJSON.a modules/JSON.kh modules/libklocalStorage.a modules/localStorage.kh modules/libkfetch.a modules/libkfetch.link modules/fetch.kh runtime/unicode_tables.c runtime/unicode_names.c

.PHONY: all test asan vsix vscode install clean
