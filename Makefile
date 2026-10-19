# Makefile - for BSD make (#193): the build is GNU make's, in GNUmakefile,
# which GNU make reads before this, so each target goes to gmake, from
# pkg install gmake or the port devel/gmake. Variables such as CC or
# PREFIX go to gmake itself: gmake install PREFIX=~/.local
GMAKE ?= gmake

# MAKEFLAGS of BSD make, as its -J, are not GNU make's
all test asan vsix vscode install clean kelvinc:
	@MAKEFLAGS= MFLAGS= $(GMAKE) $@

.DEFAULT:
	@MAKEFLAGS= MFLAGS= $(GMAKE) $@

.PHONY: all test asan vsix vscode install clean kelvinc
