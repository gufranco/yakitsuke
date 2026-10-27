SHELL := /bin/sh
PREFIX ?= $(HOME)/.local

.PHONY: help lint test test-all coverage check install

help:
	@echo "targets:"
	@echo "  lint        shellcheck -o all at zero findings"
	@echo "  test        bats suites under the system sh"
	@echo "  test-all    bats suites under every installed shell"
	@echo "  coverage    bashcov line coverage with a 100% gate"
	@echo "  check       lint and test"
	@echo "  install     copy bin/, lib/ and share/ under PREFIX (default ~/.local)"

lint:
	shellcheck -x -s sh -o all bin/yakitsuke lib/*.sh scripts/*.sh test/call.sh test/run-matrix.sh
	sh scripts/check-names.sh
	shellcheck -x -o all test/*.bash test/*.bats

test:
	YK_SHELLS=sh sh test/run-matrix.sh

test-all:
	sh test/run-matrix.sh

coverage:
	sh scripts/coverage.sh 100

check: lint test

install:
	mkdir -p "$(PREFIX)/share/yakitsuke" "$(PREFIX)/bin"
	cp -R bin lib share "$(PREFIX)/share/yakitsuke/"
	printf '#!/bin/sh\nexec "%s/share/yakitsuke/bin/yakitsuke" "$$@"\n' "$(PREFIX)" > "$(PREFIX)/bin/yakitsuke"
	chmod 755 "$(PREFIX)/bin/yakitsuke"
