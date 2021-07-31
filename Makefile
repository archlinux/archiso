#
# SPDX-License-Identifier: GPL-3.0-or-later

PREFIX ?= /usr/local
BIN_DIR=$(DESTDIR)$(PREFIX)/bin
DOC_DIR=$(DESTDIR)$(PREFIX)/share/doc/archiso
PROFILE_DIR=$(DESTDIR)$(PREFIX)/share/archiso

DOC_FILES=$(wildcard docs/*) $(wildcard *.rst)
SCRIPT_FILES=$(wildcard archiso/*) $(wildcard scripts/*.sh) $(wildcard .gitlab/ci/*.sh) \
             $(wildcard configs/*/profiledef.sh) $(wildcard configs/*/airootfs/usr/local/bin/*)

all:

check: shellcheck

shellcheck:
	shellcheck -s bash $(SCRIPT_FILES)

install: install-scripts install-profiles install-doc

install-scripts:
	install -vDm 755 archiso/mkarchiso -t "$(BIN_DIR)/"
	install -vDm 755 scripts/run_archiso.sh "$(BIN_DIR)/run_archiso"

install-profiles:
	install -d -m 755 $(PROFILE_DIR)
	cp -a --no-preserve=ownership configs $(PROFILE_DIR)/

install-doc:
	install -vDm 644 $(DOC_FILES) -t $(DOC_DIR)

.PHONY: check install install-doc install-profiles install-scripts shellcheck
