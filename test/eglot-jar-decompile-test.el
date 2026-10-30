;;; eglot-jar-decompile-test.el --- Tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'eglot-jar-decompile)

(ert-deftest eglot-jar-decompile-test-parse-posix ()
  (should (equal (eglot-jar-decompile--parse-uri
                  "jar:///tmp/lib.jar!/a/b/C.class")
                 '(:jar "/tmp/lib.jar" :entry "a/b/C.class"))))

(ert-deftest eglot-jar-decompile-test-parse-file-scheme ()
  (should (equal (eglot-jar-decompile--parse-uri
                  "jar:file:///tmp/lib.jar!/a/C.java")
                 '(:jar "/tmp/lib.jar" :entry "a/C.java"))))

(ert-deftest eglot-jar-decompile-test-parse-spaces ()
  (should (equal (eglot-jar-decompile--parse-uri
                  "jar:///tmp/my%20lib.jar!/a%20b/C.class")
                 '(:jar "/tmp/my lib.jar" :entry "a b/C.class"))))

(ert-deftest eglot-jar-decompile-test-parse-windows ()
  (should (equal (eglot-jar-decompile--parse-uri
                  "jar:file:///C:/libs/lib.jar!/a/C.class")
                 '(:jar "/C:/libs/lib.jar" :entry "a/C.class"))))

(ert-deftest eglot-jar-decompile-test-non-jar ()
  (should-not (eglot-jar-decompile--parse-uri "file:///tmp/C.class")))

(ert-deftest eglot-jar-decompile-test-nested-jar ()
  (should-error (eglot-jar-decompile--parse-uri
                 "jar:///tmp/app.jar!/BOOT-INF/lib/dep.jar!/a/C.class")
                :type 'user-error))

(defun eglot-jar-decompile-test--fixture-jar ()
  (let* ((root (make-temp-file "ejd-test-" t))
         (src (expand-file-name "a/b/C.java" root))
         (jar (expand-file-name "fixture.jar" root)))
    (make-directory (file-name-directory src) t)
    (with-temp-file src (insert "package a.b; class C {}\n"))
    (call-process "jar" nil nil nil "--create" "--file" jar "-C" root "a/b/C.java")
    (cons jar root)))

(ert-deftest eglot-jar-decompile-test-extracts-source ()
  (let* ((eglot-jar-decompile-cache-directory (make-temp-file "ejd-cache-" t))
         (fixture (eglot-jar-decompile-test--fixture-jar))
         (uri (format "jar://%s!/a/b/C.java" (car fixture)))
         (result (eglot-jar-decompile--materialize uri)))
    (should (eq (cdr result) 'source))
    (should (equal (with-temp-buffer
                     (insert-file-contents (car result))
                     (buffer-string))
                   "package a.b; class C {}\n"))))

(ert-deftest eglot-jar-decompile-test-cache-path-stable ()
  (let* ((eglot-jar-decompile-cache-directory (make-temp-file "ejd-cache-" t))
         (fixture (eglot-jar-decompile-test--fixture-jar)))
    (should (equal (eglot-jar-decompile--cache-path (car fixture) "a/b/C.java" 'source "x")
                   (eglot-jar-decompile--cache-path (car fixture) "a/b/C.java" 'source "x")))))

(ert-deftest eglot-jar-decompile-test-missing-entry ()
  (let ((eglot-jar-decompile-cache-directory (make-temp-file "ejd-cache-" t))
        (fixture (eglot-jar-decompile-test--fixture-jar)))
    (should-error (eglot-jar-decompile--materialize
                   (format "jar://%s!/no/Such.java" (car fixture)))
                  :type 'user-error)
    (should (equal (directory-files eglot-jar-decompile-cache-directory nil "\\`[^.]")
                   nil))))

(ert-deftest eglot-jar-decompile-test-no-decompiler-errors ()
  (let ((eglot-jar-decompile-decompiler 'cfr)
        (eglot-jar-decompile-decompiler-program nil)
        (exec-path nil))
    (should-error (eglot-jar-decompile--detect-decompiler) :type 'user-error)))

(ert-deftest eglot-jar-decompile-test-javap-fallback ()
  (let ((eglot-jar-decompile-decompiler 'javap)
        (eglot-jar-decompile-decompiler-program (executable-find "javap")))
    (should (eq (plist-get (eglot-jar-decompile--detect-decompiler) :type)
                'javap))))

(ert-deftest eglot-jar-decompile-test-decompiles-class ()
  (skip-unless (executable-find "javac"))
  (let* ((eglot-jar-decompile-cache-directory (make-temp-file "ejd-cache-" t))
         (root (make-temp-file "ejd-class-" t))
         (src (expand-file-name "a/b/C.java" root))
         (classes (expand-file-name "classes" root))
         (jar (expand-file-name "classes.jar" root)))
    (make-directory (file-name-directory src) t)
    (with-temp-file src (insert "package a.b; public class C { int x() { return 1; } }\n"))
    (call-process "javac" nil nil nil "-d" classes src)
    (call-process "jar" nil nil nil "--create" "--file" jar "-C" classes ".")
    (let* ((eglot-jar-decompile-decompiler 'javap)
           (result (eglot-jar-decompile--materialize
                    (format "jar://%s!/a/b/C.class" jar))))
      (should (eq (cdr result) 'decompiled))
      (should (with-temp-buffer
                (insert-file-contents (car result))
                (goto-char (point-min))
                (search-forward "class a.b.C" nil t))))))

(provide 'eglot-jar-decompile-test)
;;; eglot-jar-decompile-test.el ends here
