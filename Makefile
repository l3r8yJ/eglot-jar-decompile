EMACS ?= emacs
EL    = eglot-jar-decompile.el
TEST  = test/eglot-jar-decompile-test.el

compile:
	$(EMACS) -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile $(EL)

test:
	$(EMACS) -Q --batch -L . -L test -l $(TEST) -f ert-run-tests-batch-and-exit

lint:
	$(EMACS) -Q --batch -L . -L script -l script/lint.el

ci: compile test lint

.PHONY: compile test lint ci
