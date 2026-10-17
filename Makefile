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
RT_SRCS := $(filter-out runtime/io.c runtime/os.c runtime/regexp.c runtime/regexp_parse.c $(UD_SRCS), $(wildcard runtime/*.c))
RT_OBJS := $(RT_SRCS:runtime/%.c=build/runtime/%.o)
# IO and OS are modules (#144, #145): #import <IO> and #import <OS> bring in
# modules/IO.kh and OS.kh, whose C headers are kIO.h and kOS.h, and link
# libkIO and libkOS, the .kh + libkM form of a module (#143)
MOD_LIBS := modules/libkIO.a modules/libkOS.a
# UnicodeData (#156) is written in Kelvin over its C tables: kelvinc --lib builds
# modules/UnicodeData.kh and libkUnicodeData from modules/UnicodeData.k and the
# objects of runtime/unicode_*.c, which tools/gen_unicode.py makes from tools/ucd/
KELVIN_LIBS := modules/UnicodeData.kh modules/RegExp.kh

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

all: kelvinc modules/libkelvin.a modules/$(SHLIB) $(MOD_LIBS) $(MOD_SHLIBS) $(KELVIN_LIBS)

# kelvinc checks a $/.../ literal (#163) with the pattern parser of RegExp and the Unicode tables
CHECK_OBJS := build/runtime/regexp_parse.o build/runtime/unicode_tables.o
kelvinc: $(OBJS) $(CHECK_OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(CHECK_OBJS)

build/%.o: src/%.c src/kelvin.h | build
	$(CC) $(CFLAGS) -c -o $@ $<

build/runtime/%.o: runtime/%.c modules/kelvin_prelude.h modules/kIO.h modules/kOS.h | build/runtime
	$(CC) $(RT_CFLAGS) -Imodules -c -o $@ $<

modules/libkelvin.a: $(RT_OBJS)
	rm -f $@
	ar rcs $@ $(RT_OBJS)

modules/$(SHLIB): $(RT_OBJS)
	$(CC) $(SHLIB_FLAGS) -o $@ $(RT_OBJS) -lm

modules/libkIO.a: build/runtime/io.o
	rm -f $@
	ar rcs $@ $<

modules/libkOS.a: build/runtime/os.o
	rm -f $@
	ar rcs $@ $<

modules/libkOS.$(SO): build/runtime/os.o modules/$(SHLIB)
	$(CC) $(SHLIB_FLAGS) -o $@ $< -Lmodules -lkelvin

modules/libkIO.$(SO): build/runtime/io.o modules/libkOS.$(SO) modules/$(SHLIB)
	$(CC) $(SHLIB_FLAGS) -o $@ $< -Lmodules -lkOS -lkelvin

build/runtime/unicode_%.o: runtime/unicode_%.c modules/kelvin_prelude.h modules/kUnicodeData.h | build/runtime
	$(CC) $(RT_CFLAGS) -Wno-overlength-strings -Imodules -c -o $@ $<

# the tables, from the Unicode Character Database in tools/ucd/ (#156)
runtime/unicode_tables.c runtime/unicode_names.c: tools/gen_unicode.py $(wildcard tools/ucd/*.txt)
	python3 -I tools/gen_unicode.py

modules/UnicodeData.kh: modules/UnicodeData.k $(UD_OBJS) kelvinc modules/libkelvin.a modules/$(SHLIB)
	./kelvinc --lib modules/UnicodeData.k $(UD_OBJS) -o modules

# RegExp (#157) is written in Kelvin over its C engine, runtime/regexp.c, on UnicodeData
RX_OBJS := build/runtime/regexp.o build/runtime/regexp_parse.o
build/runtime/regexp%.o: runtime/regexp%.c runtime/regexp_internal.h modules/kelvin_prelude.h modules/kUnicodeData.h modules/kRegExp.h | build/runtime
	$(CC) $(RT_CFLAGS) -Imodules -c -o $@ $<
modules/RegExp.kh: modules/RegExp.k $(RX_OBJS) modules/UnicodeData.kh kelvinc modules/libkelvin.a modules/$(SHLIB)
	./kelvinc --lib modules/RegExp.k $(RX_OBJS) -o modules

build build/runtime:
	mkdir -p $@

test: all
	./tests/run.sh

# every test program under AddressSanitizer with a counting allocator (#175)
asan: all
	./tests/asan.sh

install: all
	install -d $(PREFIX)/bin $(PREFIX)/lib/kelvin/modules
	install -m 755 kelvinc $(PREFIX)/bin/kelvinc
	install -m 644 modules/kelvin_prelude.h modules/kIO.h modules/kOS.h modules/kUnicodeData.h modules/kRegExp.h modules/libkelvin.a $(MOD_LIBS) modules/libkUnicodeData.a modules/libkRegExp.a modules/*.k modules/*.kh $(PREFIX)/lib/kelvin/modules/
	install -m 755 modules/$(SHLIB) $(MOD_SHLIBS) modules/libkUnicodeData.$(SO) modules/libkRegExp.$(SO) $(PREFIX)/lib/kelvin/modules/

clean:
	rm -rf build kelvinc modules/libkelvin.a modules/libk*.so modules/libk*.dylib modules/libkIO.a modules/libkOS.a modules/libkUnicodeData.a modules/UnicodeData.kh modules/libkRegExp.a modules/RegExp.kh runtime/unicode_tables.c runtime/unicode_names.c

.PHONY: all test install clean
