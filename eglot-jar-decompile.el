;;; eglot-jar-decompile.el --- Jump to jar sources and decompiled classes -*- lexical-binding: t; -*-

;; Author: Ivan Ivanchuk
;; URL: https://github.com/l3r8yJ/eglot-jar-decompile
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, languages
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Resolve jar: URIs returned by Eglot and lsp-mode into real source
;; files, extracting sources jars or decompiling class files.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'xref)
(require 'url-parse)

(defgroup eglot-jar-decompile nil
  "Resolve jar: URIs into readable sources."
  :group 'tools
  :prefix "eglot-jar-decompile-")

(defcustom eglot-jar-decompile-cache-directory
  (expand-file-name
   "eglot-jar-decompile/"
   (or (getenv "XDG_CACHE_HOME") "~/.cache"))
  "Directory for extracted and decompiled files."
  :type 'directory)

(defcustom eglot-jar-decompile-decompiler 'auto
  "Decompiler to use, or `auto' to detect one."
  :type '(choice (const :tag "Auto-detect" auto)
                 (const :tag "CFR" cfr)
                 (const :tag "JD-cli" jd-cli)
                 (const :tag "Fernflower" fernflower)
                 (const :tag "javap disassembly" javap)))

(defcustom eglot-jar-decompile-decompiler-program nil
  "Path to the decompiler executable or Fernflower jar."
  :type '(choice (const :tag "Unset" nil) string))

(defcustom eglot-jar-decompile-javap-fallback t
  "Whether javap disassembly may stand in for a real decompiler."
  :type 'boolean)

(defun eglot-jar-decompile--parse-uri (uri)
  "Parse URI into a (:jar PATH :entry ENTRY) plist, or nil when not a jar URI."
  (when (and (stringp uri) (string-prefix-p "jar:" uri))
    (let* ((body (substring uri 4))
           (body (if (string-prefix-p "file://" body)
                     (substring body 7)
                   body))
           (sep (string-search "!/" body)))
      (unless sep
        (user-error "Malformed jar URI: %s" uri))
      (let ((jar (substring body 0 sep))
            (entry (substring body (+ sep 2))))
        (when (string-search "!/" entry)
          (user-error "Nested jar archives are not supported: %s" uri))
        (when (string-prefix-p "//" jar)
          (setq jar (substring jar 2)))
        (list :jar (url-unhex-string jar)
              :entry (url-unhex-string entry))))))

(defvar eglot-jar-decompile--buffer-kinds (make-hash-table :test #'equal))

(defun eglot-jar-decompile--cache-path (jar entry operation decompiler-id)
  "Return cache path for ENTRY of JAR for OPERATION and DECOMPILER-ID."
  (let* ((attrs (file-attributes jar))
         (key (secure-hash
               'sha1
               (format "%s\0%s\0%s\0%s\0%s\0%s"
                       jar entry
                       (file-attribute-size attrs)
                       (file-attribute-modification-time attrs)
                       operation decompiler-id))))
    (expand-file-name (concat key "-" (file-name-nondirectory entry))
                      eglot-jar-decompile-cache-directory)))

(defun eglot-jar-decompile--extract-entry (jar entry target)
  "Extract ENTRY from JAR into TARGET."
  (let ((work (file-name-as-directory (make-temp-file "ejd-extract-" t))))
    (unwind-protect
        (progn
          (with-temp-buffer
            (set-buffer-multibyte nil)
            (let ((default-directory work))
              (unless (zerop (call-process "jar" nil t nil
                                           "--extract" "--file" jar entry))
                (user-error "Cannot extract %s from %s" entry jar))))
          (let ((produced (expand-file-name entry work)))
            (unless (file-exists-p produced)
              (user-error "Cannot extract %s from %s" entry jar))
            (make-directory (file-name-directory target) t)
            (rename-file produced target t)))
      (delete-directory work t))))

(defun eglot-jar-decompile--fernflower-jar ()
  "Return a readable Fernflower jar path, or nil."
  (seq-find
   #'file-readable-p
   (append
    (file-expand-wildcards
     "~/.local/share/JetBrains/Toolbox/apps/*/plugins/java-decompiler/lib/java-decompiler.jar")
    (file-expand-wildcards
     "/opt/*/plugins/java-decompiler/lib/java-decompiler.jar")
    (list "/usr/share/java/fernflower.jar"
          "/usr/share/java/java-decompiler.jar"))))

(defun eglot-jar-decompile--detect-decompiler ()
  "Return a (:type TYPE :program PROGRAM) plist for the chosen decompiler."
  (let ((requested eglot-jar-decompile-decompiler)
        (program eglot-jar-decompile-decompiler-program))
    (pcase requested
      ('javap
       (if-let* ((found (and eglot-jar-decompile-javap-fallback
                             (executable-find "javap"))))
           (list :type 'javap :program found)
         (user-error "javap not found; install a JDK")))
      ('fernflower
       (let ((jar (or (and program (string-suffix-p ".jar" program) program)
                      (eglot-jar-decompile--fernflower-jar))))
         (if (and jar (file-readable-p jar))
             (list :type 'fernflower :program jar)
           (user-error "Fernflower jar not found; set `eglot-jar-decompile-decompiler-program'"))))
      ((or 'cfr 'jd-cli)
       (let ((found (or (and program (file-executable-p program) program)
                        (executable-find (symbol-name requested)))))
         (if found
             (list :type requested :program found)
           (user-error "%s not found; install it or set `eglot-jar-decompile-decompiler-program'"
                       (symbol-name requested)))))
      ('auto
       (cond
        ((and program (file-executable-p program))
         (list :type (if (string-suffix-p ".jar" program) 'fernflower 'cfr)
               :program program))
        ((executable-find "cfr")
         (list :type 'cfr :program (executable-find "cfr")))
        ((executable-find "jd-cli")
         (list :type 'jd-cli :program (executable-find "jd-cli")))
        ((eglot-jar-decompile--fernflower-jar)
         (list :type 'fernflower :program (eglot-jar-decompile--fernflower-jar)))
        ((and eglot-jar-decompile-javap-fallback (executable-find "javap"))
         (list :type 'javap :program (executable-find "javap")))
        (t
         (user-error "No Java decompiler found; install CFR, JD-cli, Fernflower, or a JDK"))))
      (_
       (user-error "Unknown `eglot-jar-decompile-decompiler': %s" requested)))))

(defun eglot-jar-decompile--decompiler-id (decompiler)
  "Return a stable identity string for DECOMPILER."
  (let ((type (plist-get decompiler :type))
        (program (plist-get decompiler :program)))
    (if (eq type 'fernflower)
        (let ((attrs (file-attributes program)))
          (format "fernflower:%s:%s:%s" program
                  (or (file-attribute-size attrs) 0)
                  (or (file-attribute-modification-time attrs) 0)))
      (format "%s:%s" type program))))

(defun eglot-jar-decompile--class-name (entry)
  "Turn jar ENTRY into a Java class name."
  (string-remove-suffix ".class" (replace-regexp-in-string "/" "." entry)))

(defun eglot-jar-decompile--javap (jar entry target)
  "Write javap disassembly of ENTRY in JAR to TARGET."
  (with-temp-buffer
    (unless (zerop (call-process "javap" nil t nil "-p" "-c" "-cp" jar
                                 (eglot-jar-decompile--class-name entry)))
      (user-error "Cannot disassemble %s from %s" entry jar))
    (write-region (point-min) (point-max) target nil 'quiet)))

(defun eglot-jar-decompile--run-decompiler (decompiler class out)
  "Run DECOMPILER on CLASS writing sources under OUT."
  (pcase (plist-get decompiler :type)
    ('cfr
     (let ((program (plist-get decompiler :program)))
       (if (string-suffix-p ".jar" program)
           (call-process "java" nil nil nil "-jar" program class "--outputdir" out)
         (call-process program nil nil nil class "--outputdir" out))))
    ('jd-cli
     (call-process (plist-get decompiler :program) nil nil nil class "-od" out))
    ('fernflower
     (call-process "java" nil nil nil "-cp" (plist-get decompiler :program)
                   "org.jetbrains.java.decompiler.main.decompiler.ConsoleDecompiler"
                   class out))))

(defun eglot-jar-decompile--decompile-entry (jar entry target decompiler)
  "Decompile ENTRY from JAR into TARGET using DECOMPILER."
  (let* ((work (file-name-as-directory (make-temp-file "ejd-decompile-" t)))
         (class (expand-file-name "input.class" work))
         (out (expand-file-name "out/" work)))
    (make-directory out t)
    (unwind-protect
        (progn
          (eglot-jar-decompile--extract-entry jar entry class)
          (make-directory (file-name-directory target) t)
          (if (eq (plist-get decompiler :type) 'javap)
              (eglot-jar-decompile--javap jar entry target)
            (eglot-jar-decompile--run-decompiler decompiler class out)
            (let ((produced (car (directory-files-recursively out "\\.java\\'"))))
              (cond
               (produced
                (copy-file produced target t))
               ((and eglot-jar-decompile-javap-fallback (executable-find "javap"))
                (eglot-jar-decompile--javap jar entry target))
               (t
                (user-error "Cannot decompile %s from %s" entry jar))))))
      (delete-directory work t))))

(defun eglot-jar-decompile--materialize-class (jar entry)
  "Materialize class ENTRY from JAR, decompiling it."
  (let* ((decompiler (eglot-jar-decompile--detect-decompiler))
         (target (eglot-jar-decompile--cache-path
                  jar entry 'decompiled
                  (eglot-jar-decompile--decompiler-id decompiler))))
    (unless (file-exists-p target)
      (eglot-jar-decompile--decompile-entry jar entry target decompiler))
    (puthash (expand-file-name target) 'decompiled
             eglot-jar-decompile--buffer-kinds)
    (cons target 'decompiled)))

(defun eglot-jar-decompile--materialize (uri)
  "Materialize URI as a local file.  Return (PATH . KIND) or nil."
  (when-let* ((parts (eglot-jar-decompile--parse-uri uri)))
    (let ((jar (plist-get parts :jar))
          (entry (plist-get parts :entry)))
      (unless (file-readable-p jar)
        (user-error "Jar not found: %s" jar))
      (if (string-suffix-p ".class" entry)
          (eglot-jar-decompile--materialize-class jar entry)
        (let ((target (eglot-jar-decompile--cache-path jar entry 'source "none")))
          (unless (file-exists-p target)
            (eglot-jar-decompile--extract-entry jar entry target))
          (puthash (expand-file-name target) 'source
                   eglot-jar-decompile--buffer-kinds)
          (cons target 'source))))))

(defvar-local eglot-jar-decompile--kind nil)

(defvar eglot-jar-decompile--eglot-function nil)

(defun eglot-jar-decompile--cache-buffer-p ()
  "Return non-nil when the current buffer visits a cache file."
  (and buffer-file-name
       (string-prefix-p
        (file-name-as-directory
         (expand-file-name eglot-jar-decompile-cache-directory))
        (expand-file-name buffer-file-name))))

(defun eglot-jar-decompile--cache-buffer-mode ()
  "Make cache buffers read-only and record what they hold."
  (when (eglot-jar-decompile--cache-buffer-p)
    (setq buffer-read-only t)
    (setq-local eglot-jar-decompile--kind
                (or (gethash (expand-file-name buffer-file-name)
                             eglot-jar-decompile--buffer-kinds)
                    'source))))

(defun eglot-jar-decompile--skip-in-cache (orig &rest args)
  "Call ORIG with ARGS unless the current buffer is a cache buffer."
  (unless (eglot-jar-decompile--cache-buffer-p)
    (apply orig args)))

(defun eglot-jar-decompile--eglot-uri-to-path (orig uri)
  "Turn jar URI into a file path, delegating to ORIG otherwise."
  (if (and (stringp uri) (string-prefix-p "jar:" uri))
      (car (eglot-jar-decompile--materialize uri))
    (funcall orig uri)))

(defun eglot-jar-decompile--install-eglot ()
  (require 'eglot)
  (setq eglot-jar-decompile--eglot-function
        (if (fboundp 'eglot-uri-to-path) 'eglot-uri-to-path 'eglot--uri-to-path))
  (advice-add eglot-jar-decompile--eglot-function
              :around #'eglot-jar-decompile--eglot-uri-to-path)
  (advice-add 'eglot-ensure :around #'eglot-jar-decompile--skip-in-cache))

(defun eglot-jar-decompile--uninstall-eglot ()
  (when (and eglot-jar-decompile--eglot-function
             (fboundp eglot-jar-decompile--eglot-function))
    (advice-remove eglot-jar-decompile--eglot-function
                   #'eglot-jar-decompile--eglot-uri-to-path))
  (when (fboundp 'eglot-ensure)
    (advice-remove 'eglot-ensure #'eglot-jar-decompile--skip-in-cache))
  (setq eglot-jar-decompile--eglot-function nil))

;;;###autoload
(define-minor-mode eglot-jar-decompile-mode
  "Resolve jar: URIs from Eglot and lsp-mode."
  :global t
  :group 'eglot-jar-decompile
  (if eglot-jar-decompile-mode
      (progn
        (eglot-jar-decompile--install-eglot)
        (add-hook 'find-file-hook #'eglot-jar-decompile--cache-buffer-mode))
    (eglot-jar-decompile--uninstall-eglot)
    (remove-hook 'find-file-hook #'eglot-jar-decompile--cache-buffer-mode)))

(provide 'eglot-jar-decompile)
;;; eglot-jar-decompile.el ends here
