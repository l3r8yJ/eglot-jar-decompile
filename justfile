emacs := "emacs"
package := "eglot-jar-decompile.el"
tests := "test/eglot-jar-decompile-test.el"

default: ci

compile:
    {{emacs}} -Q --batch -L . --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile {{package}}

test:
    {{emacs}} -Q --batch -L . -L test -l {{tests}} -f ert-run-tests-batch-and-exit

lint:
    {{emacs}} -Q --batch -L . -L script -l script/lint.el

ci: compile test lint
