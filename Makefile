SHELL := /bin/sh
PREFIX ?= $(HOME)/.local
SCRIPTS := bin/yakitsuke lib/*.sh scripts/*.sh test/*.sh test/*.bash test/*.bats

.PHONY: help fmt lint test test-all test-linux coverage check install

help:
	@echo "targets:"
	@echo "  fmt         format every script with shfmt -i 2"
	@echo "  lint        shfmt, shellcheck -o all and mandoc at zero findings"
	@echo "  test        bats suites under the system sh"
	@echo "  test-all    bats suites under every installed shell"
	@echo "  test-linux  the same suites in an Ubuntu container"
	@echo "  coverage    bashcov on this Mac and in the Ubuntu container, merged, gate 100%"
	@echo "  check       lint and test"
	@echo "  install     install the tool, man page and completions under PREFIX (default ~/.local)"

fmt:
	shfmt -i 2 -w $(SCRIPTS)

lint:
	shfmt -i 2 -d $(SCRIPTS)
	shellcheck -x -s sh -o all bin/yakitsuke lib/*.sh scripts/*.sh test/call.sh test/run-matrix.sh test/linux-container.sh
	sh scripts/check-names.sh
	shellcheck -x -o all test/*.bash test/*.bats
	shellcheck -s bash -o all completions/yakitsuke.bash
	mandoc -T lint man/yakitsuke.1

test:
	YAKITSUKE_TEST_SHELLS=sh sh test/run-matrix.sh

test-all:
	sh test/run-matrix.sh

test-linux:
	sh test/linux-container.sh sh test/run-matrix.sh

coverage:
	sh scripts/coverage.sh 0 && cp -f coverage/.resultset.json coverage-macos.json
	sh test/linux-container.sh sh scripts/linux-coverage.sh
	python3 scripts/coverage-gate.py '/(bin/yakitsuke|lib/[a-z]+\.sh)\Z' 100 coverage-macos.json coverage-linux.json

check: lint test

install:
	mkdir -p "$(PREFIX)/share/yakitsuke" "$(PREFIX)/bin" "$(PREFIX)/share/man/man1" "$(PREFIX)/share/bash-completion/completions" "$(PREFIX)/share/zsh/site-functions" "$(PREFIX)/share/fish/vendor_completions.d"
	cp -R bin lib share "$(PREFIX)/share/yakitsuke/"
	cp -f man/yakitsuke.1 "$(PREFIX)/share/man/man1/yakitsuke.1"
	cp -f completions/yakitsuke.bash "$(PREFIX)/share/bash-completion/completions/yakitsuke"
	cp -f completions/_yakitsuke "$(PREFIX)/share/zsh/site-functions/_yakitsuke"
	cp -f completions/yakitsuke.fish "$(PREFIX)/share/fish/vendor_completions.d/yakitsuke.fish"
	printf '#!/bin/sh\nexec "%s/share/yakitsuke/bin/yakitsuke" "$$@"\n' "$(PREFIX)" > "$(PREFIX)/bin/yakitsuke"
	chmod 755 "$(PREFIX)/bin/yakitsuke"
