;;; lint.el --- Run package-lint and checkdoc -*- lexical-binding: t; -*-

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))
(dolist (pkg '(package-lint))
  (unless (package-installed-p pkg)
    (package-install pkg)))
(require 'package-lint)
(require 'checkdoc)

(let ((files (directory-files default-directory t "\\`eglot-jar-decompile\\.el\\'"))
      (failed nil))
  (dolist (file files)
    (with-temp-buffer
      (insert-file-contents file)
      (emacs-lisp-mode)
      (dolist (issue (package-lint-buffer (current-buffer)))
        (message "%s:%s: %s: %s" file (nth 0 issue) (nth 2 issue) (nth 3 issue))
        (when (eq (nth 2 issue) 'error)
          (setq failed t)))))
  (dolist (file files)
    (let ((errors nil))
      (cl-letf (((symbol-function 'checkdoc-error)
                 (lambda (point msg) (push (cons point msg) errors))))
        (checkdoc-file file))
      (dolist (err errors)
        (message "%s:%s: %s" file (car err) (cdr err)))
      (when errors
        (setq failed t))))
  (when failed
    (kill-emacs 1)))

;;; lint.el ends here
