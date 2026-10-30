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

(provide 'eglot-jar-decompile-test)
;;; eglot-jar-decompile-test.el ends here
